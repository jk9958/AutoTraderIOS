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

// NOTE: Response structs below have NO explicit CodingKeys — the shared
// decoder's `.convertFromSnakeCase` maps snake_case JSON onto these camelCase
// properties (e.g. "updated_at" → updatedAt, "per_5min" → per5min). Adding
// snake_case CodingKeys here would break decoding.

struct TokenResponse: Codable {
    let status: String
    let broker: String
    let updatedAt: String
}

struct HealthResponse: Codable {
    let status: String
}

struct MessageResponse: Codable {
    let status: String
    let message: String?
    let updatedAt: String?
}

struct MetricsResponse: Codable {
    let per5min: [MetricBucket]?
    let totalLines: Int?

    struct MetricBucket: Codable {
        let interval: String?
        let lines: Int?
        let sent: Int?
        let recv: Int?
        let total: Int?
        let totalFmt: String?
    }
}

struct IronCondorParams: Encodable {
    var expiry: String
    var instrument: String = "nifty"
    var lots: Int = 1
    var spreadPts: Int = 600
    var wingPts: Int = 200
    var hardStopBuffer: Int = 50
    var profitTarget: Double = 0.50
    var slMultiplier: Double = 1.0
    var entryStart: String = "09:30"
    var entryCutoff: String = "11:00"
    var eodExit: String = "15:15"
    var holdOvernight: Bool = false
    var dryRun: Bool = true

    enum CodingKeys: String, CodingKey {
        case expiry, instrument, lots
        case spreadPts = "spread_pts"
        case wingPts = "wing_pts"
        case hardStopBuffer = "hard_stop_buffer"
        case profitTarget = "profit_target"
        case slMultiplier = "sl_multiplier"
        case entryStart = "entry_start"
        case entryCutoff = "entry_cutoff"
        case eodExit = "eod_exit"
        case holdOvernight = "hold_overnight"
        case dryRun = "dry_run"
    }
}

struct VixScalpParams: Encodable {
    var lots: Int = 1
    var minVix: Double = 14.0
    var vixSpikePct: Double = 0.015
    var vixLookback: Int = 6
    var profitTarget: Double = 0.50
    var stopLoss: Double = 0.30
    var dryRun: Bool = true

    enum CodingKeys: String, CodingKey {
        case lots
        case minVix = "min_vix"
        case vixSpikePct = "vix_spike_pct"
        case vixLookback = "vix_lookback"
        case profitTarget = "profit_target"
        case stopLoss = "stop_loss"
        case dryRun = "dry_run"
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
