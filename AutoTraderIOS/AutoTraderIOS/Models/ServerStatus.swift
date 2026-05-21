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

    var isPaperTrading: Bool { paperTrading == "true" }

    func tokenColor(for broker: String) -> String {
        let val = tokens[broker] ?? ""
        if val.contains("updated") || val.contains("loaded") { return "green" }
        if val == "not set" || val.isEmpty { return "grey" }
        return "orange"
    }
}
