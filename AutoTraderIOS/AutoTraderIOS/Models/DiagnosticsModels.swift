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
    let reason: String?
    var level: HealthLevel { HealthLevel(raw: status) }
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
