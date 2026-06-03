import Foundation

// MARK: - Launch Params (Encodable — uses a plain JSONEncoder, so snake_case
// CodingKeys ARE required here and are honored).

struct TrendAgentParams: Encodable {
    var symbols: [String] = ["NIFTY"]
    var capital: Double = 200_000
    var riskPct: Double = 1.5
    var minConfidence: Double = 0.55
    var scanInterval: Int = 300
    var maxTrades: Int = 2
    var adaptive: Bool = true
    var dryRun: Bool = true

    enum CodingKeys: String, CodingKey {
        case symbols, capital, adaptive
        case riskPct = "risk_pct"
        case minConfidence = "min_confidence"
        case scanInterval = "scan_interval"
        case maxTrades = "max_trades"
        case dryRun = "dry_run"
    }
}

// MARK: - Decodable responses
// All decoded by the shared `.convertFromSnakeCase` decoder, so properties are
// camelCase with NO explicit CodingKeys (snake_case keys would break decoding).
// Dictionary keys (e.g. positions map, tf_weights, recent_trades rows) are
// left untouched by the strategy and remain snake_case.

struct TrendAgentStatus: Decodable {
    let running: Bool
    let engine: String?
    let startedAt: String?
    let exitCode: Int?
    let logLines: Int?
    let openPositions: Int?
    let positions: [String: TrendPosition]?
}

struct TrendPosition: Decodable, Identifiable {
    let tradingsymbol: String?
    let optionType: String?
    let quantity: Int?
    let lotSize: Int?
    let entryPrice: Double?
    let stopLoss: Double?
    let target1: Double?
    let target2: Double?
    let entryTime: String?
    let spotAtEntry: Double?
    let confidence: Double?
    let status: String?
    let t1Booked: Bool?
    let currentPrice: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double?
    let orderId: String?

    var id: String { (tradingsymbol ?? "") + (entryTime ?? "") }

    var isOpen: Bool { (status ?? "").lowercased() == "open" }
    var livePnl: Double { (unrealizedPnl ?? 0) + (realizedPnl ?? 0) }
}

struct TrendSignals: Decodable {
    let openPositions: [TrendPosition]?
    let closedToday: [TrendPosition]?
    let recentTrades: [[String: String]]?
    let savedAt: String?
}

struct TrendTradesResponse: Decodable {
    let trades: [[String: String]]?
}

struct TrendLearning: Decodable {
    let adaptiveParams: AdaptiveParams?
    let learningHistory: [LearningCycle]?
    let tradeSummary: TradeSummary?
}

struct AdaptiveParams: Decodable {
    let version: Int?
    let minConfidence: Double?
    let slPct: Double?
    let target1Pct: Double?
    let target2Pct: Double?
    let ivRankMax: Double?
    let adxMin: Double?
    let avoidSessions: [String]?
    let avoidConditions: [String]?
    let tfWeights: [String: Double]?
    let atmConfidenceMin: Double?
    let otm1ConfidenceMin: Double?
    let lastWinRate: Double?
    let lastAvgPnl: Double?
    let totalPnl: Double?
    let cycleCount: Int?
}

struct LearningCycle: Decodable, Identifiable {
    let cycle: Int?
    let nTrades: Int?
    let winRate: Double?
    let avgPnl: Double?
    let totalPnl: Double?
    let timestamp: String?

    var id: Int { cycle ?? 0 }
}

struct TradeSummary: Decodable {
    let totalClosed: Int?
    let wins: Int?
    let winRate: Double?
    let totalPnl: Double?
}
