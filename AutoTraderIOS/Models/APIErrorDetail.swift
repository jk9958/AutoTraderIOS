import Foundation

struct APIErrorDetail: Codable, Sendable {
    let loc: [LocElement]
    let msg: String
    let type: String

    var fieldName: String? {
        // loc is typically ["body", "field_name"]
        loc.compactMap { $0.stringValue }.last
    }
}

// Handles mixed-type loc arrays: strings and ints
enum LocElement: Codable, Sendable {
    case string(String)
    case int(Int)

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i):    try container.encode(i)
        }
    }
}
