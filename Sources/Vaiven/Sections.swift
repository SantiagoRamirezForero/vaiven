import AppKit
import VaivenCore

/// Panel del cursor: un solo botón ancho, sin títulos ni textos.
@MainActor
final class CursorSectionView: NSView {
    static let height: CGFloat = 44
    var onPress: (() -> Void)?
    private var button: NSButton!

    override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Palette.columnWidth, height: Self.height))
        appearance = NSAppearance(named: .darkAqua)
        button = Palette.makeTile(target: self, action: #selector(pressed))
        button.frame = bounds
        addSubview(button)
        update(active: false, failed: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    /// `failed`: no se pudo reservar Esc y por eso no arrancó.
    func update(active: Bool, failed: Bool) {
        let title = active ? "Parar · Esc" : failed ? "Esc no disponible" : "Mover cursor"
        Palette.styleTile(button, title: title, symbol: "cursorarrow.motionlines", active: active, failed: failed)
    }

    @objc private func pressed() { onPress?() }
}

/// Una fila de uso: nombre y %, barra de 4 pt y texto de reinicio.
@MainActor
final class UsageRowView: NSView {
    static let height: CGFloat = 40
    private let name = Palette.label(size: 12, weight: .medium)
    private let percent = Palette.label(size: 12, weight: .semibold, alignment: .right)
    private let track = CALayer()
    private let fill = CALayer()
    private let reset = Palette.label(size: 11, color: Palette.textSecondary)
    private let base: NSColor

    init(title: String, base: NSColor) {
        self.base = base
        super.init(frame: NSRect(x: 0, y: 0, width: Palette.columnWidth, height: Self.height))
        wantsLayer = true
        name.stringValue = title
        percent.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        name.frame = NSRect(x: 0, y: Self.height - 16, width: 120, height: 16)
        percent.frame = NSRect(x: 120, y: Self.height - 16, width: Palette.columnWidth - 120, height: 16)
        track.frame = CGRect(x: 0, y: Self.height - 24, width: Palette.columnWidth, height: 4)
        track.cornerRadius = 2
        track.backgroundColor = Palette.track.cgColor
        fill.cornerRadius = 2
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        reset.frame = NSRect(x: 0, y: 0, width: Palette.columnWidth, height: 14)
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
        for view in [name, percent, reset] { addSubview(view) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    func update(_ view: UsageWindowView?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let view {
            let color = Palette.usage(view.level, base: base)
            percent.stringValue = "\(view.pct) %"
            percent.textColor = color
            fill.backgroundColor = color.cgColor
            fill.bounds = CGRect(x: 0, y: 0, width: Palette.columnWidth * view.fraction, height: 4)
            fill.position = CGPoint(x: 0, y: track.frame.midY)
            fill.isHidden = view.fraction <= 0
            reset.stringValue = view.resetText
        } else {
            percent.stringValue = "–"
            percent.textColor = Palette.textSecondary
            fill.isHidden = true
            reset.stringValue = ""
        }
        CATransaction.commit()
    }
}

/// Panel de Claude. Con cuenta: «Claude» y el estado arriba, sesión de 5 h, semana y «Sincronizar».
/// Sin cuenta: una línea y «Agregar cuenta».
@MainActor
final class ClaudeSectionView: NSView {
    static let connectedHeight: CGFloat = 18 + 8 + UsageRowView.height + 6 + UsageRowView.height + 12 + 36
    static let connectHeight: CGFloat = 16 + 10 + 36

    var onPress: (() -> Void)?
    private let title = Palette.label(size: 13, weight: .semibold)
    private let status = Palette.label(size: 11, color: Palette.textSecondary, alignment: .right)
    private let session = UsageRowView(title: "Sesión 5 h", base: Palette.session)
    private let week = UsageRowView(title: "Semana", base: Palette.week)
    private var button: NSButton!
    private var shown: ClaudePresentation?

    override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Palette.columnWidth, height: Self.connectedHeight))
        appearance = NSAppearance(named: .darkAqua)
        title.stringValue = "Claude"
        button = Palette.makeTile(target: self, action: #selector(pressed))
        for view: NSView in [title, status, session, week, button] { addSubview(view) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    static func height(connected: Bool) -> CGFloat { connected ? connectedHeight : connectHeight }

    func update(_ presentation: ClaudePresentation) {
        guard presentation != shown else { return }
        let relayout = presentation.connected != shown?.connected
        shown = presentation
        if relayout { layoutContent(connected: presentation.connected) }
        status.stringValue = presentation.statusText
        status.textColor = presentation.statusIsError ? Palette.red : Palette.textSecondary
        session.update(presentation.five)
        week.update(presentation.week)
        Palette.styleTile(button, title: presentation.buttonTitle,
                          symbol: presentation.connected ? "arrow.clockwise" : "person.crop.circle.badge.plus")
        button.isEnabled = presentation.buttonEnabled
        button.alphaValue = presentation.buttonEnabled ? 1 : 0.5
    }

    private func layoutContent(connected: Bool) {
        let height = Self.height(connected: connected)
        setFrameSize(NSSize(width: Palette.columnWidth, height: height))
        let width = Palette.columnWidth
        title.isHidden = !connected
        session.isHidden = !connected
        week.isHidden = !connected
        if connected {
            title.frame = NSRect(x: 0, y: height - 18, width: 70, height: 18)
            status.frame = NSRect(x: 70, y: height - 18, width: width - 70, height: 18)
            status.alignment = .right
            session.frame.origin = NSPoint(x: 0, y: height - 26 - UsageRowView.height)
            week.frame.origin = NSPoint(x: 0, y: height - 26 - 2 * UsageRowView.height - 6)
        } else {
            status.frame = NSRect(x: 0, y: height - 16, width: width, height: 16)
            status.alignment = .left
        }
        button.frame = NSRect(x: 0, y: 0, width: width, height: 36)
    }

    @objc private func pressed() { onPress?() }
}
