import Foundation

// MARK: - Mobile API v1 — multi-engine management
//
// Source of truth: Auto_Option/src/api_server.py (tags=["mobile"]).
// Read endpoints are open; write endpoints require the X-API-Key header.
//
// Decoding convention (see CLAUDE.md): the shared decoder uses
// `.convertFromSnakeCase`, so DECODABLE response models use camelCase with NO
// CodingKeys (engine_id → engineId, last_beat → lastBeat). ENCODABLE request
// models are encoded with a plain JSONEncoder and DO need snake_case CodingKeys.

// MARK: - Enumerations (mirror server validation)

enum EngineBroker: String, CaseIterable, Identifiable, Codable {
    case fyers, kite, tradesmart
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fyers: return "Fyers"
        case .kite: return "Kite (Zerodha)"
        case .tradesmart: return "TradeSmart"
        }
    }
}

enum EngineStrategy: String, CaseIterable, Identifiable, Codable {
    case ironCondor = "iron_condor"
    case vixScalp   = "vix_scalp"
    case trend
    var id: String { rawValue }

    /// Engineer-facing name (kept for advanced screens).
    var displayName: String {
        switch self {
        case .ironCondor: return "Iron Condor"
        case .vixScalp: return "VIX Scalp"
        case .trend: return "Trend Agent"
        }
    }

    /// Novice-facing name (see plan glossary).
    var friendlyName: String {
        switch self {
        case .ironCondor: return "Range Income"
        case .vixScalp:   return "Volatility Spike"
        case .trend:      return "Trend Follower"
        }
    }

    var subtitle: String {
        switch self {
        case .ironCondor: return "Earns when the market stays calm and range-bound."
        case .vixScalp:   return "Trades quick moves when the market gets jumpy."
        case .trend:      return "Rides sustained up or down moves."
        }
    }

    var iconName: String {
        switch self {
        case .ironCondor: return "arrow.left.and.right"
        case .vixScalp:   return "bolt.fill"
        case .trend:      return "chart.line.uptrend.xyaxis"
        }
    }

    enum Risk: String { case lower = "Lower risk", higher = "Higher risk" }
    var risk: Risk {
        switch self {
        case .ironCondor: return .lower
        case .vixScalp:   return .higher
        case .trend:      return .higher
        }
    }

    /// Friendly name for a raw strategy string coming back from the server.
    static func friendlyName(forRaw raw: String?) -> String {
        guard let raw, let s = EngineStrategy(rawValue: raw) else { return raw ?? "—" }
        return s.friendlyName
    }
}

/// systemctl actions exposed by the mobile API.
enum EngineLifecycleAction: String {
    case start, stop, restart
}

/// Heartbeat-derived lifecycle state reported by the server.
enum EngineRunState: String {
    case running = "RUNNING"
    case stale   = "STALE"
    case stopped = "STOPPED"
    case unknown

    init(raw: String?) { self = EngineRunState(rawValue: raw?.uppercased() ?? "") ?? .unknown }
}

// MARK: - Decodable responses

/// One engine's heartbeat snapshot (`/api/v1/engines`, `/status`).
struct EngineInfo: Decodable, Identifiable, Equatable {
    let engineId: String
    let broker: String?
    let strategy: String?
    let status: String?
    let pid: Int?
    let lastBeat: String?
    let stale: Bool?

    var id: String { engineId }
    var runState: EngineRunState { EngineRunState(raw: status) }
}

struct EnginesListResponse: Decodable {
    let ok: Bool
    let engines: [EngineInfo]
    let error: String?
}

struct EngineStatusResponse: Decodable {
    let ok: Bool
    let engine: EngineInfo
}

struct EngineConfigResponse: Decodable {
    let ok: Bool
    let engineId: String
    let config: JSONValue
}

/// Covers POST create / start / stop / restart / delete responses, all of which
/// share `ok` + `engine_id` and a subset of the remaining optional fields.
struct EngineActionResponse: Decodable {
    let ok: Bool
    let engineId: String?
    let status: String?
    let unit: String?
    let configPath: String?
    let secretsPath: String?
    let autostarted: Bool?
    let autostartError: String?
    let note: String?
}

struct RotateKeyResponse: Decodable {
    let ok: Bool
    let updatedAt: String?
    let note: String?
}

// MARK: - Encodable requests (plain JSONEncoder → snake_case CodingKeys required)

struct CreateEngineRequest: Encodable {
    var engineId: String
    var broker: String
    var strategy: String
    var params: [String: JSONValue] = [:]
    var accessToken: String = ""
    var telegramBotToken: String = ""
    var telegramChatId: String = ""
    var autostart: Bool = false

    enum CodingKeys: String, CodingKey {
        case engineId = "engine_id"
        case broker, strategy, params
        case accessToken = "access_token"
        case telegramBotToken = "telegram_bot_token"
        case telegramChatId = "telegram_chat_id"
        case autostart
    }
}

struct PatchEngineConfigRequest: Encodable {
    var params: [String: JSONValue] = [:]
    var extra: [String: JSONValue] = [:]
}

struct EngineTokenRequest: Encodable {
    var accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
}

struct RotateKeyRequest: Encodable {
    var apiKey: String
    enum CodingKeys: String, CodingKey { case apiKey = "api_key" }
}

// MARK: - Client-side validation (mirrors server regex / rules)

enum EngineValidation {
    /// Server: `^[A-Za-z0-9_-]+$`
    static func isValidEngineId(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }

    /// Turn a friendly bot name ("My Range Bot") into a valid engine_id
    /// ("my_range_bot"). Collapses runs of invalid chars to a single underscore.
    static func slugify(_ name: String) -> String {
        let lowered = name.lowercased()
        let mapped = lowered.map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "-") ? ch : "_"
        }
        var slug = String(mapped)
        while slug.contains("__") { slug = slug.replacingOccurrences(of: "__", with: "_") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return slug
    }
    /// Server: rotation key must be ≥ 12 chars.
    static func isValidApiKey(_ key: String) -> Bool { key.count >= 12 }
}
