import Foundation

struct TradesResponse: Codable {
    let trades: [[String: AnyCodable]]
}

enum AnyCodable: Codable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([AnyCodable])
    case object([String: AnyCodable])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            // Never throw — a single odd value must not fail the whole trades list.
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return String(b)
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .array(let a): return a.map(\.stringValue).joined(separator: ", ")
        case .object(let o): return o.map { "\($0.key): \($0.value.stringValue)" }.joined(separator: ", ")
        case .null: return ""
        }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let b): return b
        case .string(let s): return s.lowercased() == "true"
        default: return false
        }
    }
}
