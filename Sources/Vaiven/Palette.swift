import AppKit
import VaivenCore

/// Colores y medidas de la isla.
enum Palette {
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }

    static let blue = hex(0x58a6ff)
    static let gray = hex(0x8b949e)
    static let red = hex(0xf85149)
    static let amber = hex(0xd29922)
    static let session = hex(0xf0883e)
    static let week = hex(0x58a6ff)
    static let track = NSColor(white: 1, alpha: 0.16)
    static let tile = NSColor(white: 1, alpha: 0.08)
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor(white: 1, alpha: 0.62)

    static func usage(_ level: UsageLevel, base: NSColor) -> NSColor {
        switch level {
        case .normal: return base
        case .amber: return amber
        case .red: return red
        case .gray: return gray
        }
    }

    // Medidas de la isla abierta.
    static let columnWidth: CGFloat = 248
    /// De la barra al panel, y del panel al borde de abajo.
    static let bodyGap: CGFloat = 12
    static let bottomMargin: CGFloat = 14
    static let collapsedRadius: CGFloat = 10
    static let expandedRadius: CGFloat = 22

    static func label(size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = textPrimary,
                      alignment: NSTextAlignment = .left) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = alignment
        field.lineBreakMode = .byTruncatingTail
        field.drawsBackground = false
        return field
    }

    /// Un SF Symbol pintado en un cuadrado de `iconSize` (para el `contents` de un CALayer de las alas).
    static func symbolImage(_ name: String, color: NSColor, scale: CGFloat, inset: CGFloat = 0) -> CGImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let image = base.withSymbolConfiguration(config) else { return nil }
        let side = IslandGeometry.iconSize
        let drawn = NSImage(size: NSSize(width: side * scale, height: side * scale), flipped: false) { full in
            let rect = full.insetBy(dx: inset * scale, dy: inset * scale)
            let ratio = image.size.width / max(image.size.height, 1)
            let w = ratio >= 1 ? rect.width : rect.height * ratio
            let h = ratio >= 1 ? rect.width / ratio : rect.height
            image.draw(in: NSRect(x: rect.minX + (rect.width - w) / 2, y: rect.minY + (rect.height - h) / 2, width: w, height: h))
            return true
        }
        return drawn.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Botón ancho de los paneles: icono a la izquierda del texto, fondo tenue; azul si su acción corre, rojo si falló.
    static func styleTile(_ button: NSButton, title: String, symbol: String, active: Bool = false, failed: Bool = false) {
        let color = active ? blue : failed ? red : textPrimary
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        button.attributedTitle = NSAttributedString(string: "  " + title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: color])
        button.layer?.backgroundColor = (active ? blue.withAlphaComponent(0.18) : tile).cgColor
    }

    static func makeTile(target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: target, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleNone
        button.imageHugsTitle = true
        return button
    }
}
