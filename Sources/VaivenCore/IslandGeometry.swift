import CoreGraphics
import Foundation

/// Lo que se necesita de cada pantalla (se llena desde NSScreen; aquí no hay AppKit).
public struct ScreenInfo: Equatable, Sendable {
    public var frame: CGRect
    public var safeAreaTop: CGFloat
    public var leftAuxWidth: CGFloat
    public var rightAuxWidth: CGFloat
    public var menuBarHeight: CGFloat

    public init(frame: CGRect, safeAreaTop: CGFloat, leftAuxWidth: CGFloat = 0,
                rightAuxWidth: CGFloat = 0, menuBarHeight: CGFloat = 0) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.leftAuxWidth = leftAuxWidth
        self.rightAuxWidth = rightAuxWidth
        self.menuBarHeight = menuBarHeight
    }
}

/// Con notch, una ala a cada lado del notch; sin notch, una píldora arriba al centro.
public enum IslandMode: Equatable, Sendable { case notch, pill }

/// Rectángulos de la isla en coordenadas globales de AppKit (origen abajo a la izquierda).
public struct IslandLayout: Equatable, Sendable {
    public var mode: IslandMode
    public var screenFrame: CGRect
    /// El notch real (en la píldora, la píldora).
    public var notch: CGRect
    /// Plegada: ala del cursor, notch y ala de Claude (o la píldora).
    public var collapsed: CGRect
    /// Ancho de la isla abierta: centrada en la pantalla, pegada arriba.
    public var expandedWidth: CGFloat

    public init(mode: IslandMode, screenFrame: CGRect, notch: CGRect, collapsed: CGRect, expandedWidth: CGFloat) {
        self.mode = mode; self.screenFrame = screenFrame; self.notch = notch
        self.collapsed = collapsed; self.expandedWidth = expandedWidth
    }

    /// Ancho del ala izquierda (cursor): 34 junto al notch, la mitad de la píldora sin él.
    public var leftWingWidth: CGFloat { mode == .notch ? IslandGeometry.leftWingWidth : IslandGeometry.pillWidth / 2 }

    /// Dónde empieza el ala derecha (Claude): el borde derecho del notch o el centro de la píldora.
    public var rightWingX: CGFloat { mode == .notch ? notch.maxX : collapsed.minX + IslandGeometry.pillWidth / 2 }

    /// La isla abierta con un alto dado: el borde de arriba no se mueve.
    public func expanded(height: CGFloat) -> CGRect {
        CGRect(x: screenFrame.midX - expandedWidth / 2, y: screenFrame.maxY - height, width: expandedWidth, height: height)
    }
}

public enum IslandGeometry {
    public static let leftWingWidth: CGFloat = 34
    public static let rightWingWidth: CGFloat = 40
    public static let iconSize: CGFloat = 22
    public static let pillWidth: CGFloat = 84
    public static let pillDefaultHeight: CGFloat = 24
    public static let expandedMinWidth: CGFloat = 280

    /// La primera pantalla con notch (aunque no sea la principal); sin ninguna, la principal en píldora.
    public static func layout(screens: [ScreenInfo]) -> IslandLayout? {
        if let screen = screens.first(where: { $0.safeAreaTop > 0 }) { return notchLayout(screen) }
        guard let main = screens.first else { return nil }
        return pillLayout(main)
    }

    /// Dónde va el icono del cursor desde el borde izquierdo de su ala.
    public static func cursorIconX(mode: IslandMode) -> CGFloat { mode == .notch ? 8 : pillWidth / 2 - 2 - iconSize }

    /// Dónde va el anillo de Claude desde el borde izquierdo de su ala.
    public static func ringX(mode: IslandMode) -> CGFloat { mode == .notch ? 8 : 2 }

    static func notchLayout(_ screen: ScreenInfo) -> IslandLayout {
        let frame = screen.frame
        let height = screen.safeAreaTop
        let width = frame.width - screen.leftAuxWidth - screen.rightAuxWidth
        let notch = CGRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
        let collapsed = CGRect(x: notch.minX - leftWingWidth, y: notch.minY,
                               width: leftWingWidth + width + rightWingWidth, height: height)
        // Abierta debe cubrir las dos alas: ancho simétrico hasta el ala más lejos del centro.
        let reach = width / 2 + max(leftWingWidth, rightWingWidth)
        return IslandLayout(mode: .notch, screenFrame: frame, notch: notch, collapsed: collapsed,
                            expandedWidth: max(expandedMinWidth, 2 * reach))
    }

    static func pillLayout(_ screen: ScreenInfo) -> IslandLayout {
        let frame = screen.frame
        let height = screen.menuBarHeight > 0 ? screen.menuBarHeight : pillDefaultHeight
        let pill = CGRect(x: frame.midX - pillWidth / 2, y: frame.maxY - height, width: pillWidth, height: height)
        return IslandLayout(mode: .pill, screenFrame: frame, notch: pill, collapsed: pill, expandedWidth: expandedMinWidth)
    }
}
