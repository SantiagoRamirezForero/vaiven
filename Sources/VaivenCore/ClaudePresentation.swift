import Foundation

/// Por qué no se pudo leer el uso.
public enum ClaudeSyncError: String, Error, Equatable, Sendable {
    /// No hay sesión de Claude Code en el Llavero.
    case noLogin
    /// La sesión de Claude Code venció (Claude Code la renueva al abrirse).
    case expired
    /// Claude respondió 401 o 403.
    case rejected
    case offline
    case other

    public var text: String {
        switch self {
        case .noLogin: return "No hay sesión de Claude Code en esta Mac"
        case .expired: return "Sesión vencida: abre Claude Code"
        case .rejected: return "Claude rechazó la sesión: abre Claude Code"
        case .offline: return "Sin conexión"
        case .other: return "No se pudo leer el uso"
        }
    }
}

/// El color final depende de la ventana (sesión o semana) y del nivel.
public enum UsageLevel: String, Sendable { case normal, amber, red, gray }

public struct UsageWindowView: Equatable, Sendable {
    public let pct: Int
    public let level: UsageLevel
    /// 0…1, para el ancho de la barra.
    public let fraction: Double
    public let resetText: String
}

/// Lo que se ve de Claude en el anillo y en su panel.
public struct ClaudePresentation: Equatable, Sendable {
    /// Sin cuenta: el anillo muestra «+» y el panel ofrece «Agregar cuenta».
    public let connected: Bool
    public let five: UsageWindowView?
    public let week: UsageWindowView?
    /// Arriba a la derecha del panel: «hace 3 min», «Sincronizando…» o el error.
    public let statusText: String
    public let statusIsError: Bool
    public let buttonTitle: String
    public let buttonEnabled: Bool
    public let accessibility: String

    /// Pasados 20 min sin leer (se lee cada 5), los números se ven grises.
    public static let staleAfter: TimeInterval = 20 * 60

    public static func make(connected: Bool, usage: ClaudeUsage?, syncing: Bool, error: ClaudeSyncError?,
                            now: Date = Date()) -> ClaudePresentation {
        guard connected else {
            return ClaudePresentation(
                connected: false, five: nil, week: nil,
                statusText: syncing ? "Buscando la sesión…" : error?.text ?? "Usa tu sesión de Claude Code",
                statusIsError: error != nil && !syncing, buttonTitle: "Agregar cuenta", buttonEnabled: !syncing,
                accessibility: "Claude: sin cuenta")
        }
        let stale = usage.map { now.timeIntervalSince($0.fetchedAt) > staleAfter } ?? false
        let five = usage?.five.map { view($0, stale: stale, now: now) }
        let week = usage?.week.map { view($0, stale: stale, now: now) }
        let status: String
        if syncing {
            status = "Sincronizando…"
        } else if let error {
            status = error.text
        } else if let usage {
            status = RelativeText.age(from: usage.fetchedAt, now: now)
        } else {
            status = ""
        }
        return ClaudePresentation(
            connected: true, five: five, week: week, statusText: status, statusIsError: error != nil && !syncing,
            buttonTitle: "Sincronizar", buttonEnabled: !syncing,
            accessibility: five.map { "Claude: \($0.pct) % de la sesión" } ?? "Claude: sin datos")
    }

    static func view(_ window: UsageWindow, stale: Bool, now: Date) -> UsageWindowView {
        // Si la ventana ya se reinició, el dato guardado no vale: 0 % hasta la próxima lectura.
        if window.resetsAt <= now {
            return UsageWindowView(pct: 0, level: stale ? .gray : .normal, fraction: 0, resetText: "se reinició")
        }
        let value = min(100, max(0, window.pct))
        return UsageWindowView(pct: Int(value.rounded()), level: stale ? .gray : level(for: value),
                               fraction: value / 100, resetText: RelativeText.resetText(window.resetsAt, now: now))
    }

    /// Ámbar desde 75 %, rojo desde 90 %.
    public static func level(for pct: Double) -> UsageLevel {
        pct >= 90 ? .red : pct >= 75 ? .amber : .normal
    }
}
