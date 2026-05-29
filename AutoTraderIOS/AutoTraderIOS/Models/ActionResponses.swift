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

    enum CodingKeys: String, CodingKey {
        case status, broker
        case updatedAt = "updated_at"
    }
}

struct HealthResponse: Codable {
    let status: String
}

struct MessageResponse: Codable {
    let status: String
    let message: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, message
        case updatedAt = "updated_at"
    }
}

struct MetricsResponse: Codable {
    let per5min: [MetricBucket]?
    let totalLines: Int?

    enum CodingKeys: String, CodingKey {
        case per5min = "per_5min"
        case totalLines = "total_lines"
    }

    struct MetricBucket: Codable {
        let window: String?
        let calls: Int?
        let bytes: Int?
    }
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
