import CoreGraphics
import Foundation
import Testing
@testable import VaivenCore

@Suite struct GeometryTests {
    /// Una MacBook Air de 13" con notch: 1512 x 982 pt, notch de 185 x 32.
    static let builtIn = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                    leftAuxWidth: 663.5, rightAuxWidth: 663.5, menuBarHeight: 33)
    static let external = ScreenInfo(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), safeAreaTop: 0, menuBarHeight: 24)

    @Test func theCursorWingGoesLeftOfTheNotchAndClaudeRight() throws {
        let layout = try #require(IslandGeometry.layout(screens: [Self.builtIn]))
        #expect(layout.mode == .notch)
        #expect(layout.notch == CGRect(x: 663.5, y: 950, width: 185, height: 32))
        #expect(layout.collapsed == CGRect(x: 629.5, y: 950, width: 259, height: 32))
        #expect(layout.leftWingWidth == 34)
        #expect(layout.rightWingX == layout.notch.maxX)
    }

    @Test func theOpenIslandIsCenteredAndCoversBothWings() throws {
        let layout = try #require(IslandGeometry.layout(screens: [Self.builtIn]))
        let open = layout.expanded(height: 100)
        #expect(open == CGRect(x: 616, y: 882, width: 280, height: 100))
        #expect(open.minX <= layout.collapsed.minX && open.maxX >= layout.collapsed.maxX)
        #expect(open.maxY == Self.builtIn.frame.maxY)
    }

    @Test func aWideNotchWidensTheOpenIsland() throws {
        let wide = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeAreaTop: 38,
                              leftAuxWidth: 744, rightAuxWidth: 744, menuBarHeight: 38)
        let layout = try #require(IslandGeometry.layout(screens: [wide]))
        #expect(layout.expandedWidth == CGFloat(320)) // notch of 240 plus the farthest wing (40) on each side
    }

    @Test func prefersTheNotchScreenEvenIfItIsNotTheMainOne() throws {
        let layout = try #require(IslandGeometry.layout(screens: [Self.external, Self.builtIn]))
        #expect(layout.mode == .notch && layout.collapsed.minX == 629.5)
    }

    @Test func withoutNotchItIsAPillCenteredOnTopOfTheMainScreen() throws {
        let layout = try #require(IslandGeometry.layout(screens: [Self.external]))
        #expect(layout.mode == .pill)
        #expect(layout.collapsed == CGRect(x: -960 - 42, y: 1056, width: 84, height: 24))
        #expect(layout.rightWingX == -960)
        #expect(layout.expanded(height: 90).midX == -960)
        #expect(IslandGeometry.layout(screens: []) == nil)
    }
}

@Suite struct StateTests {
    @Test func eachWingOpensItsPanelAndASecondClickCloses() {
        var state = IslandState()
        #expect(state.click(wing: .claude) == .expand && state.panel == .claude)
        #expect(state.click(wing: .cursor) == .none) // still animating
        state.animationFinished()
        #expect(state.click(wing: .cursor) == .switchPanel && state.panel == .cursor)
        #expect(state.click(wing: .cursor) == .collapse)
        state.animationFinished()
        #expect(state.phase == .collapsed)
    }

    @Test func closeOnlyActsWhenOpen() {
        var state = IslandState()
        #expect(state.close() == .none)
        _ = state.click(wing: .cursor)
        #expect(state.close() == .none) // opening: the controller closes it when the animation ends
        state.animationFinished()
        #expect(state.close() == .collapse)
    }

    @Test func aScreenChangeFoldsAtOnce() {
        var state = IslandState()
        _ = state.click(wing: .cursor)
        #expect(state.screenChanged() == .collapseImmediately && state.phase == .collapsed)
        #expect(state.screenChanged() == .none)
    }
}

@Suite struct CursorSweepTests {
    @Test func swingsRightThenLeftAroundTheCenterOnOneLine() {
        let sweep = CursorSweep(display: CGRect(x: 0, y: 0, width: 1512, height: 982))
        let quarter = CursorSweep.period / 4
        #expect(sweep.point(at: 0) == CGPoint(x: 756, y: 491))
        #expect(abs(sweep.point(at: quarter).x - 916) < 0.001)
        #expect(abs(sweep.point(at: 3 * quarter).x - 596) < 0.001)
        #expect(sweep.point(at: 1.7).y == 491)
    }

    @Test func aNarrowScreenGetsAShorterSwing() {
        let sweep = CursorSweep(display: CGRect(x: -400, y: 0, width: 400, height: 800))
        #expect(sweep.amplitude == 100 && sweep.center == CGPoint(x: -200, y: 400))
    }
}

@Suite struct ClaudeApiTests {
    static let response = """
    {"five_hour": {"utilization": 42.0, "resets_at": "2026-11-18T23:00:00.123456+00:00", "locked_reason": null},
     "seven_day": {"utilization": 65.0, "resets_at": "2026-11-21T14:00:00.654321+00:00"},
     "seven_day_opus": null, "extra_usage": {"is_enabled": false}}
    """

    @Test func readsTheSessionAndTheWeekWithMicroseconds() throws {
        let now = Date()
        let usage = try #require(ClaudeUsageAPI.parse(Data(Self.response.utf8), fetchedAt: now))
        #expect(usage.five?.pct == 42 && usage.week?.pct == 65 && usage.fetchedAt == now)
        #expect(usage.five?.resetsAt == RelativeText.parseISO("2026-11-18T23:00:00Z"))
    }

    @Test func aResponseWithoutWindowsIsNoData() {
        #expect(ClaudeUsageAPI.parse(Data(#"{"five_hour": null, "seven_day": null}"#.utf8), fetchedAt: Date()) == nil)
        #expect(ClaudeUsageAPI.parse(Data("no es json".utf8), fetchedAt: Date()) == nil)
    }

    @Test func readsClaudeCodesKeychainEntryAndNeverPrintsTheToken() throws {
        let entry = #"{"claudeAiOauth": {"accessToken": "token-de-prueba-secreto", "refreshToken": "x", "expiresAt": 1800000000000}}"#
        let credentials = try #require(ClaudeCredentials.parse(Data((entry + "\n").utf8)))
        #expect(credentials.accessToken == "token-de-prueba-secreto")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(credentials.isExpired(now: Date(timeIntervalSince1970: 1_800_000_001)))
        #expect(!"\(credentials)".contains("secreto"))
    }

    @Test func anEntryWithoutTokenIsNoLogin() {
        #expect(ClaudeCredentials.parse(Data(#"{"mcpOAuth": {}}"#.utf8)) == nil)
        #expect(ClaudeCredentials.parse(Data()) == nil)
    }
}

@Suite struct ClaudePresentationTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func usage(five: Double, fetchedAgo: TimeInterval = 60) -> ClaudeUsage {
        ClaudeUsage(five: UsageWindow(pct: five, resetsAt: now.addingTimeInterval(3600)),
                    week: UsageWindow(pct: 30, resetsAt: now.addingTimeInterval(86400 * 3)),
                    fetchedAt: now.addingTimeInterval(-fetchedAgo))
    }

    @Test func withoutAccountItOffersToAddIt() {
        let p = ClaudePresentation.make(connected: false, usage: nil, syncing: false, error: nil, now: now)
        #expect(!p.connected && p.buttonTitle == "Agregar cuenta" && p.buttonEnabled && p.five == nil)
    }

    @Test func noClaudeCodeLoginIsShownInRed() {
        let p = ClaudePresentation.make(connected: false, usage: nil, syncing: false, error: .noLogin, now: now)
        #expect(p.statusIsError && p.statusText == "No hay sesión de Claude Code en esta Mac")
    }

    @Test func connectedShowsBothWindowsAndHowOldTheyAre() {
        let p = ClaudePresentation.make(connected: true, usage: usage(five: 80), syncing: false, error: nil, now: now)
        #expect(p.five?.pct == 80 && p.five?.level == .amber && p.week?.pct == 30)
        #expect(p.statusText == "hace 1 min" && p.buttonTitle == "Sincronizar")
    }

    @Test func syncingDisablesTheButton() {
        let p = ClaudePresentation.make(connected: true, usage: usage(five: 10), syncing: true, error: nil, now: now)
        #expect(!p.buttonEnabled && p.statusText == "Sincronizando…" && !p.statusIsError)
    }

    @Test func oldDataTurnsGrayAndAFailureKeepsTheLastNumbers() {
        let p = ClaudePresentation.make(connected: true, usage: usage(five: 95, fetchedAgo: 3600), syncing: false,
                                        error: .offline, now: now)
        #expect(p.five?.pct == 95 && p.five?.level == .gray)
        #expect(p.statusText == "Sin conexión" && p.statusIsError)
    }

    @Test func aWindowThatAlreadyResetReadsZero() {
        let old = ClaudeUsage(five: UsageWindow(pct: 70, resetsAt: now.addingTimeInterval(-10)), week: nil, fetchedAt: now)
        let p = ClaudePresentation.make(connected: true, usage: old, syncing: false, error: nil, now: now)
        #expect(p.five?.pct == 0 && p.five?.resetText == "se reinició")
    }
}
