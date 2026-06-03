import Foundation

struct ServerStatus: Codable {
    let running: Bool
    let engine: String?
    let startedAt: String?
    let exitCode: Int?
    let logLines: Int?
    let tokens: [String: String]?
    let paperTrading: String?
    let nextExpiry: String?
    let fyersAccessToken: String?

    // NOTE: No explicit CodingKeys. The shared decoder uses
    // `.convertFromSnakeCase`, which maps e.g. "started_at" → startedAt
    // automatically. Adding snake_case CodingKeys here would BREAK decoding
    // (the strategy converts the JSON key before matching the CodingKey).

    var isPaperTrading: Bool { paperTrading == "true" || paperTrading == "1" }

    func tokenColor(for broker: String) -> String {
        let val = tokens?[broker] ?? ""
        if val.contains("updated") || val.contains("loaded") || val.contains("active") { return "green" }
        if val == "not set" || val.isEmpty { return "grey" }
        return "orange"
    }
}
