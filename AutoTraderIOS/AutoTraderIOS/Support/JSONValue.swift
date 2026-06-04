import Foundation

/// A type-erased JSON value for the mobile API's free-form `params` / `config`
/// payloads (engine config is YAML decoded to an arbitrary JSON object server-side).
/// Both Codable directions are supported so it can be sent in `params`/`extra`
/// and decoded back from `GET /api/v1/engines/{id}/config`.
enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    /// Human-readable rendering for config/diagnostic display.
    var displayString: String {
        switch self {
        case .string(let v): return v
        case .int(let v):    return String(v)
        case .double(let v): return String(v)
        case .bool(let v):   return v ? "true" : "false"
        case .null:          return "—"
        case .array(let a):  return a.map(\.displayString).joined(separator: ", ")
        case .object(let o): return o.map { "\($0.key): \($0.value.displayString)" }.joined(separator: ", ")
        }
    }

    /// Flatten a top-level object into sorted (key, value) display rows.
    var sortedObjectRows: [(key: String, value: JSONValue)] {
        guard case .object(let o) = self else { return [] }
        return o.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Reads `params.dry_run` from an engine config object, if present.
    /// Returns true=Practice, false=Live, nil=unknown.
    var dryRunFlag: Bool? {
        guard case .object(let root) = self,
              case .object(let params)? = root["params"],
              case .bool(let b)? = params["dry_run"] else { return nil }
        return b
    }
}
