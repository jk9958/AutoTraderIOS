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

    enum CodingKeys: String, CodingKey {
        case running
        case engine
        case startedAt = "started_at"
        case exitCode = "exit_code"
        case logLines = "log_lines"
        case tokens
        case paperTrading = "paper_trading"
        case nextExpiry = "next_expiry"
    }

    var isPaperTrading: Bool { paperTrading == "true" }

    func tokenColor(for broker: String) -> String {
        let val = tokens[broker] ?? ""
        if val.contains("updated") || val.contains("loaded") { return "green" }
        if val == "not set" || val.isEmpty { return "grey" }
        return "orange"
    }
}
