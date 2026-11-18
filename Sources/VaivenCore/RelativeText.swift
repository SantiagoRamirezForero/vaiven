import Foundation

/// Textos de tiempo relativo en español neutro.
public enum RelativeText {
    /// «hace unos segundos», «hace 3 min», «hace 2 h», «hace 4 d».
    public static func age(from date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "hace unos segundos" }
        if seconds < 3600 { return "hace \(Int(seconds / 60)) min" }
        if seconds < 86400 { return "hace \(Int(seconds / 3600)) h" }
        return "hace \(Int(seconds / 86400)) d"
    }

    /// «se reinicia en 51 min», «en 4h 20m», «en 2d 5h».
    public static func resetText(_ date: Date, now: Date) -> String {
        let minutes = max(0, Int((date.timeIntervalSince(now) / 60).rounded()))
        if minutes < 60 { return "se reinicia en \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 {
            let rest = minutes % 60
            return rest >= 10 && hours < 5 ? "se reinicia en \(hours)h \(rest)m" : "se reinicia en \(hours)h"
        }
        let days = hours / 24
        let extra = hours % 24
        return extra == 0 ? "se reinicia en \(days)d" : "se reinicia en \(days)d \(extra)h"
    }

    nonisolated(unsafe) static let iso = ISO8601DateFormatter()

    /// Fechas ISO 8601 con o sin fracción de segundo. Anthropic manda microsegundos («…:00.123456+00:00»), que
    /// `ISO8601DateFormatter` no siempre acepta: la fracción se descarta.
    public static func parseISO(_ text: String) -> Date? {
        iso.date(from: text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression))
    }
}
