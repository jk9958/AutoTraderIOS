import Foundation

/// One running (or recently-seen) engine from `GET /api/v1/engines`.
/// Decoded with the shared `.convertFromSnakeCase` decoder — camelCase, NO CodingKeys.
struct EngineHeartbeat: Decodable, Identifiable, Hashable {
    let engineId: String
    let status: String?
    let pid: Int?
    let lastBeat: String?
    let stale: Bool?
    let strategy: String?
    let broker: String?
    let dryRun: Bool?

    var id: String { engineId }

    /// Normalised lifecycle state for the status pill.
    var state: EngineState {
        if stale == true { return .stale }
        switch (status ?? "").uppercased() {
        case "RUNNING", "ACTIVE", "UP": return .running
        case "STOPPED", "DOWN", "INACTIVE", "DEAD": return .stopped
        default: return pid != nil ? .running : .stopped
        }
    }
}

enum EngineState {
    case running, stale, stopped

    var label: String {
        switch self {
        case .running: return "RUNNING"
        case .stale: return "STALE"
        case .stopped: return "STOPPED"
        }
    }
}

/// `GET /api/v1/engines` may return either a bare array or `{ "engines": [...] }`.
struct EnginesResponse: Decodable {
    let engines: [EngineHeartbeat]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let arr = try? single.decode([EngineHeartbeat].self) {
            engines = arr
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        engines = try keyed.decodeIfPresent([EngineHeartbeat].self, forKey: .engines) ?? []
    }

    enum CodingKeys: String, CodingKey { case engines }
}
