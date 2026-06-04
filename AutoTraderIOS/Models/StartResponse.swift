import Foundation

struct StartResponse: Codable {
    let status: String
    let engine: String?
    let command: [String]?
}
