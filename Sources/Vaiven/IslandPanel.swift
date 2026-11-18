import AppKit

/// Ventana de la isla: sin marco ni sombra, sobre la barra de menú, en todos los Spaces.
@MainActor
final class IslandPanel: NSPanel {
    /// Sobre la barra de menú (24) y los ítems de estado (25); bajo los menús emergentes (101).
    static let islandLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)

    /// Solo abierta puede ser la ventana de teclado (para recibir Esc).
    var isExpanded = false
    var onEscape: (() -> Void)?
    var onResignKey: (() -> Void)?

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = Self.islandLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { isExpanded }
    override var canBecomeMain: Bool { false }

    /// AppKit empuja las ventanas fuera de la barra de menú; la isla debe quedar pegada al borde superior.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
