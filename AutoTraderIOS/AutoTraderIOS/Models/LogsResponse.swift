import Foundation

struct LogsResponse: Codable {
    let source: String?
    let lines: [String]
}
