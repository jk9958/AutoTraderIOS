import Foundation
import os.log

/// Privacy-safe analytics events. No PII, no tokens/keys — only coarse product
/// signals. Wire a real backend later behind `AnalyticsClient` if desired.
enum AnalyticsEvent {
    case onboardingCompleted
    case botCreated(strategy: String, live: Bool)
    case botStarted(live: Bool)
    case botStopped
    case botDeleted
    case brokerConnected(broker: String)
    case errorShown(type: String)

    var name: String {
        switch self {
        case .onboardingCompleted: return "onboarding_completed"
        case .botCreated:          return "bot_created"
        case .botStarted:          return "bot_started"
        case .botStopped:          return "bot_stopped"
        case .botDeleted:          return "bot_deleted"
        case .brokerConnected:     return "broker_connected"
        case .errorShown:          return "error_shown"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .botCreated(let s, let live): return ["strategy": s, "mode": live ? "live" : "practice"]
        case .botStarted(let live):        return ["mode": live ? "live" : "practice"]
        case .brokerConnected(let b):      return ["broker": b]
        case .errorShown(let t):           return ["type": t]
        default:                            return [:]
        }
    }
}

protocol AnalyticsClient {
    func track(_ event: AnalyticsEvent)
}

/// Default no-op so the app has zero external dependencies; swap in DI/tests.
struct NoopAnalytics: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}

/// Logs to the unified log (DEBUG builds) — handy while developing.
struct ConsoleAnalytics: AnalyticsClient {
    private let logger = Logger(subsystem: "com.autotrader.ios", category: "Analytics")
    func track(_ event: AnalyticsEvent) {
        let params = event.parameters.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.log("event \(event.name, privacy: .public) \(params, privacy: .public)")
    }
}

enum Analytics {
    #if DEBUG
    static let shared: AnalyticsClient = ConsoleAnalytics()
    #else
    static let shared: AnalyticsClient = NoopAnalytics()
    #endif
}
