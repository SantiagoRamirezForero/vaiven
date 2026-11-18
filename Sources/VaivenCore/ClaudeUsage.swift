import Foundation

public struct UsageWindow: Equatable, Sendable {
    /// 0…100.
    public var pct: Double
    public var resetsAt: Date
    public init(pct: Double, resetsAt: Date) { self.pct = pct; self.resetsAt = resetsAt }
}

/// Uso de la cuenta de Claude: sesión de 5 h y semana.
public struct ClaudeUsage: Equatable, Sendable {
    public var five: UsageWindow?
    public var week: UsageWindow?
    /// Cuándo se leyó.
    public var fetchedAt: Date
    public init(five: UsageWindow?, week: UsageWindow?, fetchedAt: Date) {
        self.five = five; self.week = week; self.fetchedAt = fetchedAt
    }
}

/// El endpoint que usa `/usage` de Claude Code (no es una API pública: puede cambiar).
public enum ClaudeUsageAPI {
    public static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    public static let betaHeader = "oauth-2025-04-20"

    private struct Raw: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        let five_hour: Window?
        let seven_day: Window?
    }

    /// Lee la respuesta. nil si no se decodifica o no trae ninguna ventana.
    public static func parse(_ data: Data, fetchedAt: Date) -> ClaudeUsage? {
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        let five = window(raw.five_hour)
        let week = window(raw.seven_day)
        guard five != nil || week != nil else { return nil }
        return ClaudeUsage(five: five, week: week, fetchedAt: fetchedAt)
    }

    private static func window(_ raw: Raw.Window?) -> UsageWindow? {
        guard let raw, let pct = raw.utilization, let text = raw.resets_at, let date = RelativeText.parseISO(text) else { return nil }
        return UsageWindow(pct: pct, resetsAt: date)
    }
}

/// La sesión de Claude Code que macOS guarda en el Llavero («Claude Code-credentials»). Solo vive en memoria
/// mientras se pide el uso: nunca se escribe ni se muestra.
public struct ClaudeCredentials: Equatable, Sendable, CustomStringConvertible {
    public static let keychainService = "Claude Code-credentials"

    public let accessToken: String
    public let expiresAt: Date?

    public init(accessToken: String, expiresAt: Date?) { self.accessToken = accessToken; self.expiresAt = expiresAt }

    private struct Raw: Decodable {
        struct OAuth: Decodable {
            let accessToken: String?
            /// Milisegundos desde 1970.
            let expiresAt: Double?
        }
        let claudeAiOauth: OAuth?
    }

    /// Lo que guarda Claude Code: `{"claudeAiOauth": {"accessToken": …, "expiresAt": ms, …}}`.
    public static func parse(_ data: Data) -> ClaudeCredentials? {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = try? JSONDecoder().decode(Raw.self, from: Data(text.utf8)),
              let token = raw.claudeAiOauth?.accessToken, !token.isEmpty else { return nil }
        return ClaudeCredentials(accessToken: token,
                                 expiresAt: raw.claudeAiOauth?.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) })
    }

    public func isExpired(now: Date) -> Bool { expiresAt.map { $0 <= now } ?? false }

    /// Nunca muestra el token (ni en un `print` ni en un log).
    public var description: String { "ClaudeCredentials(<oculto>)" }
}
