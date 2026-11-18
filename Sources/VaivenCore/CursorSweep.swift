import CoreGraphics
import Foundation

/// Vaivén horizontal del cursor en el centro de una pantalla, en coordenadas de Core Graphics
/// (origen arriba a la izquierda, como `CGDisplayBounds`). Puro: sin AppKit.
public struct CursorSweep: Equatable, Sendable {
    /// Segundos de una ida y vuelta.
    public static let period: TimeInterval = 2.4
    /// Distancia máxima desde el centro hacia cada lado.
    public static let maxAmplitude: CGFloat = 160

    public let center: CGPoint
    public let amplitude: CGFloat

    /// `bounds`: la pantalla en coordenadas globales de Core Graphics.
    public init(display bounds: CGRect) {
        center = CGPoint(x: bounds.midX, y: bounds.midY)
        amplitude = min(Self.maxAmplitude, bounds.width / 4)
    }

    /// Dónde va el cursor `elapsed` segundos después de empezar: sale del centro hacia la derecha y vuelve.
    public func point(at elapsed: TimeInterval) -> CGPoint {
        let phase = 2 * Double.pi * elapsed / Self.period
        return CGPoint(x: center.x + amplitude * CGFloat(sin(phase)), y: center.y)
    }
}
