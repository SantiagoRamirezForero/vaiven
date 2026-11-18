import Foundation

public enum IslandPhase: Equatable, Sendable { case collapsed, expanding, expanded, collapsing }

/// Cada ala abre su panel: la izquierda el cursor, la derecha el uso de Claude.
public enum IslandWing: Equatable, Sendable { case cursor, claude }

public enum IslandEffect: Equatable, Sendable {
    case none
    case expand
    /// Con la isla abierta se tocó la otra ala: cambia de panel sin cerrar.
    case switchPanel
    case collapse
    /// Cambio de pantallas: plegada al instante, sin animación.
    case collapseImmediately
}

/// Máquina de estados de la isla, pura: decide qué hacer; la vista anima.
public struct IslandState: Equatable, Sendable {
    public private(set) var phase: IslandPhase = .collapsed
    /// El panel que se muestra (o se mostrará al abrir).
    public private(set) var panel: IslandWing = .cursor
    public init() {}

    /// Está abriendo o cerrando.
    public var isBusy: Bool { phase == .expanding || phase == .collapsing }

    /// Clic en un ala: abre su panel, cambia a él o, si ya se ve, cierra. Animándose, nada.
    public mutating func click(wing: IslandWing) -> IslandEffect {
        switch phase {
        case .collapsed:
            panel = wing
            phase = .expanding
            return .expand
        case .expanded:
            if wing == panel { phase = .collapsing; return .collapse }
            panel = wing
            return .switchPanel
        case .expanding, .collapsing:
            return .none
        }
    }

    /// Esc, clic afuera, clic en la franja de arriba o el vaivén arrancó: cierra si está abierta.
    public mutating func close() -> IslandEffect {
        guard phase == .expanded else { return .none }
        phase = .collapsing
        return .collapse
    }

    public mutating func screenChanged() -> IslandEffect {
        guard phase != .collapsed else { return .none }
        phase = .collapsed
        return .collapseImmediately
    }

    public mutating func animationFinished() {
        switch phase {
        case .expanding: phase = .expanded
        case .collapsing: phase = .collapsed
        default: break
        }
    }
}
