import AppKit
import VaivenCore

/// Ala izquierda: el cursor con estelas, gris en reposo y azul mientras se mueve. Solo un CALayer con la imagen.
@MainActor
final class CursorWingView: NSView {
    private static let restOpacity: Float = 0.85
    private let icon = CALayer()
    private var drawnActive: Bool?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        icon.contentsGravity = .resizeAspect
        icon.opacity = Self.restOpacity
        layer?.addSublayer(icon)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func layoutIcon(x: CGFloat) {
        let size = IslandGeometry.iconSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        icon.frame = CGRect(x: x, y: (bounds.height - size) / 2, width: size, height: size)
        icon.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    func update(active: Bool) {
        setAccessibilityLabel(active ? "Moviendo el cursor, Esc para parar" : "Mover cursor")
        guard active != drawnActive else { return }
        drawnActive = active
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        icon.contents = Palette.symbolImage("cursorarrow.motionlines", color: active ? Palette.blue : Palette.gray,
                                            scale: window?.backingScaleFactor ?? 2, inset: 1)
        CATransaction.commit()
    }

    /// El brillo sube un 15 % al pasar el mouse.
    func setHover(_ inside: Bool) { icon.opacity = inside ? 1 : Self.restOpacity }
}

/// Ala derecha: anillo de 22 pt con el % de la sesión de 5 h adentro; «+» si no hay cuenta.
@MainActor
final class UsageRingView: NSView {
    private static let lineWidth: CGFloat = 2.5
    private let track = CAShapeLayer()
    private let arc = CAShapeLayer()
    private let number = Palette.label(size: 9.5, weight: .semibold, alignment: .center)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let side = IslandGeometry.iconSize
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: side / 2, y: side / 2), radius: side / 2 - Self.lineWidth / 2,
                    startAngle: .pi / 2, endAngle: -3 * .pi / 2, clockwise: true)
        for layer in [track, arc] {
            layer.path = path
            layer.fillColor = nil
            layer.lineWidth = Self.lineWidth
            layer.lineCap = .round
            self.layer?.addSublayer(layer)
        }
        track.strokeColor = Palette.track.cgColor
        arc.strokeEnd = 0
        arc.opacity = 0.85
        number.lineBreakMode = .byClipping
        addSubview(number)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func layoutRing(x: CGFloat) {
        let side = IslandGeometry.iconSize
        let box = CGRect(x: x, y: (bounds.height - side) / 2, width: side, height: side)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = box
        arc.frame = box
        CATransaction.commit()
        number.frame = box.insetBy(dx: 1, dy: 5)
    }

    func setHover(_ inside: Bool) { arc.opacity = inside ? 1 : 0.85 }

    func update(_ presentation: ClaudePresentation) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setAccessibilityLabel(presentation.accessibility)
        if let five = presentation.five {
            let color = Palette.usage(five.level, base: Palette.session)
            arc.strokeColor = color.cgColor
            arc.strokeEnd = max(0.001, five.fraction)
            arc.isHidden = five.fraction == 0
            number.stringValue = "\(five.pct)"
            number.font = .monospacedDigitSystemFont(ofSize: five.pct >= 100 ? 8 : 9.5, weight: .semibold)
            number.textColor = color
        } else {
            arc.isHidden = true
            number.stringValue = presentation.connected ? "–" : "+"
            number.font = .monospacedDigitSystemFont(ofSize: presentation.connected ? 9.5 : 12, weight: .semibold)
            number.textColor = Palette.gray
        }
        CATransaction.commit()
    }
}
