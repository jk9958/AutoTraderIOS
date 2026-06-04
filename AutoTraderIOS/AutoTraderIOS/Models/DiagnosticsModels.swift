import Foundation

// MARK: - GET /health/deep
//
// Server shape: { status: "HEALTHY|DEGRADED|FAILED",
//                 components: { <name>: { status, reason } } }

enum HealthLevel: String {
    case healthy  = "HEALTHY"
    case degraded = "DEGRADED"
    case failed   = "FAILED"
    case unknown

    init(raw: String?) { self = HealthLevel(rawValue: raw?.uppercased() ?? "") ?? .unknown }

    var appStatus: AppStatus {
        switch self {
        case .healthy:  return .healthy
        case .degraded: return .warning
        case .failed:   return .error
        case .unknown:  return .unknown
        }
    }
}

struct ComponentHealth: Decodable {
    let status: String?
    /// `reason` may be a plain string OR an object (e.g. dashboard_processes returns
    /// `{vix: bool, trend: bool}`), so decode it flexibly and render to text.
    private let reasonValue: JSONValue?

    var level: HealthLevel { HealthLevel(raw: status) }
    var reason: String? {
        switch reasonValue {
        case .none, .some(.null): return nil
        case .some(let v):
            let s = v.displayString
            return s.isEmpty ? nil : s
        }
    }

    enum CodingKeys: String, CodingKey { case status, reason }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        reasonValue = try? c.decodeIfPresent(JSONValue.self, forKey: .reason)
    }
}

struct HealthDeepResponse: Decodable {
    let status: String?
    let components: [String: ComponentHealth]?
    var overall: HealthLevel { HealthLevel(raw: status) }

    /// Stable, display-sorted component rows.
    var sortedComponents: [(name: String, health: ComponentHealth)] {
        (components ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}

// MARK: - GET /scalping/mtm  → { mtm: <state|null>, market_open: Bool }

struct ScalpingMTMResponse: Decodable {
    let marketOpen: Bool?
    let mtm: JSONValue?

    var hasOpenPositions: Bool {
        if case .object = mtm { return true }
        return false
    }
}
