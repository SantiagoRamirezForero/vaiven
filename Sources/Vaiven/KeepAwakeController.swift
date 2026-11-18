import AppKit
import Carbon.HIToolbox
import IOKit.pwr_mgt
import VaivenCore

/// «Mover cursor»: el cursor va de lado a lado en el centro de la pantalla para que la Mac no se bloquee mientras se
/// espera (por ejemplo a Claude). Esc lo para y deja el cursor donde estaba.
///
/// - Esc es un atajo global de Carbon (`RegisterEventHotKey`): no pide permiso de accesibilidad y solo existe mientras
///   el cursor se mueve. Si no se puede reservar, no se arranca (sería un cursor imposible de parar con el teclado).
/// - El cursor se mueve con `CGWarpMouseCursorPosition` (tampoco pide permisos). Como mover el cursor así no cuenta
///   como actividad, además se toma la aserción «no apagar la pantalla por inactividad» (lo que hace `caffeinate -d`)
///   y cada 30 s se declara actividad del usuario.
/// - Se para solo si la Mac se duerme, se bloquea la pantalla o se cambia de usuario.
@MainActor
final class KeepAwakeController {
    private static let tick: TimeInterval = 1.0 / 60
    private static let activityEvery: CFTimeInterval = 30
    private static let assertionName = "Vaivén: mover cursor" as CFString
    /// 'plso'
    private static let hotKeyID = EventHotKeyID(signature: OSType(0x706C_736F), id: 1)

    /// Cuándo empezó a moverse el cursor (nil = quieto).
    private(set) var startedAt: Date?
    var isActive: Bool { startedAt != nil }
    var onChange: (() -> Void)?

    private var timer: DispatchSourceTimer?
    private var sweep: CursorSweep?
    /// Dónde estaba el cursor al empezar: ahí vuelve al parar.
    private var origin: CGPoint?
    private var startedMedia: CFTimeInterval = 0
    private var lastActivity: CFTimeInterval = 0
    private var displayAssertion = IOPMAssertionID(0)
    private var activityAssertion = IOPMAssertionID(0)
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    /// Empieza a mover el cursor. Devuelve false si no se pudo reservar Esc (y entonces no se movió nada).
    @discardableResult
    func start() -> Bool {
        guard !isActive else { return true }
        guard registerEscape() else { return false }
        let cursor = CGEvent(source: nil)?.location ?? .zero
        origin = cursor
        sweep = CursorSweep(display: Self.displayBounds(containing: cursor))
        startedAt = Date()
        startedMedia = CACurrentMediaTime()
        lastActivity = startedMedia
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn), Self.assertionName, &displayAssertion)
        declareActivity()
        observeStops()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: Self.tick, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.step() } }
        timer.resume()
        self.timer = timer
        onChange?()
        return true
    }

    /// Para, suelta Esc y las aserciones, y devuelve el cursor a donde estaba.
    func stop() {
        guard isActive else { return }
        timer?.cancel()
        timer = nil
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        for id in [displayAssertion, activityAssertion] where id != 0 { IOPMAssertionRelease(id) }
        displayAssertion = 0
        activityAssertion = 0
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        if let origin { move(to: origin) }
        origin = nil
        sweep = nil
        startedAt = nil
        onChange?()
    }

    private func step() {
        guard let sweep else { return }
        let now = CACurrentMediaTime()
        move(to: sweep.point(at: now - startedMedia))
        if now - lastActivity >= Self.activityEvery {
            lastActivity = now
            declareActivity()
        }
    }

    private func move(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        // Sin esto el mouse físico queda congelado un cuarto de segundo tras cada salto.
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// Reinicia el contador de inactividad del sistema (el que usan el protector de pantalla y el bloqueo).
    private func declareActivity() {
        IOPMAssertionDeclareUserActivity(Self.assertionName, kIOPMUserActiveLocal, &activityAssertion)
    }

    /// La pantalla donde está el cursor, en coordenadas globales de Core Graphics.
    private static func displayBounds(containing point: CGPoint) -> CGRect {
        var display = CGDirectDisplayID(0)
        var count: UInt32 = 0
        CGGetDisplaysWithPoint(point, 1, &display, &count)
        return CGDisplayBounds(count > 0 ? display : CGMainDisplayID())
    }

    // MARK: Esc

    private func registerEscape() -> Bool {
        if hotKeyHandler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let me = Unmanaged.passUnretained(self).toOpaque()
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<KeepAwakeController>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { controller.stop() }
                return noErr
            }, 1, &spec, me, &hotKeyHandler)
            guard status == noErr else { hotKeyHandler = nil; return false }
        }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_Escape), 0, Self.hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKey = ref
        return true
    }

    // MARK: paradas automáticas

    private func observeStops() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let stopNow: @Sendable (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.stop() } }
        observers = [
            (workspace, workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: stopNow)),
            (workspace, workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main,
                                              using: stopNow)),
            (distributed, distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main,
                                                  using: stopNow)),
        ]
    }
}
