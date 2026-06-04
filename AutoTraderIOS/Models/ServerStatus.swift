import Foundation

struct ServerStatus: Codable {
    let running: Bool
    let engine: String?
    let startedAt: String?
    let exitCode: Int?
    let logLines: Int
    let tokens: [String: String]
    let paperTrading: String
    let nextExpiry: String

    var isLive: Bool {
        paperTrading.lowercased() == "false"
    }

    var formattedStartTime: String? {
        guard let startedAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: startedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: date)
        }
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: startedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: date)
        }
        return startedAt
    }

    func startDate() -> Date? {
        guard let startedAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: startedAt) { return date }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: startedAt)
    }

    func elapsed() -> String {
        guard let date = startDate() else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        }
        return String(format: "%dm %02ds", m, s)
    }

    func tokenStatus(for broker: String) -> TokenStatus {
        guard let value = tokens[broker] else { return .notSet }
        let lower = value.lowercased()
        if lower == "not set" || lower.isEmpty { return .notSet }
        if lower.contains("updated") || lower.contains("loaded") { return .ok }
        return .stale
    }
}

enum TokenStatus {
    case ok
    case stale
    case notSet

    var label: String {
        switch self {
        case .ok:     return "OK"
        case .stale:  return "Stale"
        case .notSet: return "Not Set"
        }
    }
}
