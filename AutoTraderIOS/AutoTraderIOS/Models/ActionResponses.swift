import Foundation

struct StartResponse: Codable {
    let status: String
    let engine: String?
    let command: [String]?
}

struct StopResponse: Codable {
    let status: String
    let engine: String?
}

struct TokenResponse: Codable {
    let status: String
    let broker: String
    let updatedAt: String
}

struct HealthResponse: Codable {
    let status: String
}

struct IronCondorParams: Encodable {
    var expiry: String
    var instrument: String = "nifty"
    var lots: Int = 1
    var spreadPts: Int = 400
    var wingPts: Int = 200
    var profitTarget: Double = 0.50
    var slMultiplier: Double = 1.0
    var entryStart: String = "09:30"
    var entryCutoff: String = "11:00"
    var eodExit: String = "15:15"
    var dryRun: Bool = true

    enum CodingKeys: String, CodingKey {
        case expiry, instrument, lots
        case spreadPts = "spread_pts"
        case wingPts = "wing_pts"
        case profitTarget = "profit_target"
        case slMultiplier = "sl_multiplier"
        case entryStart = "entry_start"
        case entryCutoff = "entry_cutoff"
        case eodExit = "eod_exit"
        case dryRun = "dry_run"
    }
}

// MARK: - v2 Engine launch

/// Body for `POST /api/v2/engines/launch`. Encoded with a *plain* JSONEncoder,
/// so it NEEDS explicit snake_case CodingKeys (per the project decode convention).
struct LaunchRequest: Encodable {
    var strategy: String          // "iron-condor" | "vix-scalp" | "trend"
    var broker: String            // "fyers" | "kite" | "tradesmart"
    var dryRun: Bool = true

    // Iron Condor only (all optional)
    var instrument: String?       // "nifty" | "sensex"
    var expiry: String?
    var lots: Int?
    var spreadPts: Int?
    var wingPts: Int?
    var profitTarget: Double?
    var slMultiplier: Double?
    var entryStart: String?
    var entryCutoff: String?
    var eodExit: String?

    enum CodingKeys: String, CodingKey {
        case strategy, broker, instrument, expiry, lots
        case dryRun = "dry_run"
        case spreadPts = "spread_pts"
        case wingPts = "wing_pts"
        case profitTarget = "profit_target"
        case slMultiplier = "sl_multiplier"
        case entryStart = "entry_start"
        case entryCutoff = "entry_cutoff"
        case eodExit = "eod_exit"
    }
}

struct LaunchResponse: Decodable {
    let status: String?
    let engineId: String?
    let message: String?
}

// MARK: - Health (deep)

/// `GET /health/deep` — overall status plus per-component checks.
/// Modelled defensively; `components` is a free-form map of name → reason.
struct HealthDeepResponse: Decodable {
    let status: String?
    let components: [HealthComponent]

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: DynamicKey.self)
        status = try? keyed.decode(String.self, forKey: DynamicKey(stringValue: "status")!)
        if let comps = try? keyed.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey(stringValue: "components")!) {
            components = comps.allKeys.map { key in
                let raw = try? comps.decode(HealthRaw.self, forKey: key)
                return HealthComponent(name: key.stringValue, ok: raw?.ok, reason: raw?.reasonText)
            }
        } else {
            components = []
        }
    }

    /// Component value may be a string, a bool, or an object `{ ok, reason }`.
    private struct HealthRaw: Decodable {
        let ok: Bool?
        let reasonText: String?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { ok = b; reasonText = nil; return }
            if let s = try? c.decode(String.self) {
                reasonText = s
                ok = s.localizedCaseInsensitiveContains("ok") || s.localizedCaseInsensitiveContains("up")
                return
            }
            let keyed = try decoder.container(keyedBy: DynamicKey.self)
            ok = try? keyed.decode(Bool.self, forKey: DynamicKey(stringValue: "ok")!)
            // reason can itself be an object — collapse to a short string.
            if let r = try? keyed.decode(String.self, forKey: DynamicKey(stringValue: "reason")!) {
                reasonText = r
            } else {
                reasonText = nil
            }
        }
    }
}

struct HealthComponent: Identifiable, Hashable {
    let name: String
    let ok: Bool?
    let reason: String?
    var id: String { name }
}

// MARK: - Alerts

/// `GET /api/v2/alerts`
struct AlertsResponse: Decodable {
    let alerts: [Alert]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let arr = try? single.decode([Alert].self) {
            alerts = arr
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        alerts = try keyed.decodeIfPresent([Alert].self, forKey: .alerts) ?? []
    }

    enum CodingKeys: String, CodingKey { case alerts }
}

struct Alert: Decodable, Identifiable, Hashable {
    let id: String
    let severity: String?
    let message: String?
    let timestamp: String?
    let source: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        func str(_ k: String) -> String? { try? c.decode(String.self, forKey: DynamicKey(stringValue: k)!) }
        severity = str("severity") ?? str("level")
        message = str("message") ?? str("text") ?? str("detail")
        timestamp = str("timestamp") ?? str("time") ?? str("createdAt")
        source = str("source") ?? str("component")
        id = str("id") ?? "\(timestamp ?? "")-\(message ?? UUID().uuidString)"
    }

    enum Severity { case critical, warning, info }
    var level: Severity {
        switch (severity ?? "").uppercased() {
        case "CRITICAL", "ERROR", "FATAL": return .critical
        case "WARNING", "WARN": return .warning
        default: return .info
        }
    }
}

// Used for 422 validation error parsing
struct ValidationErrorItem: Decodable {
    let loc: [JSONAnyValue]
    let msg: String
    let type: String
}

enum JSONAnyValue: Decodable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        self = .string("")
    }
}
