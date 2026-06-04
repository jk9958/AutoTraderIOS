import Foundation

enum Endpoint {
    case health
    case status
    case logs(lines: Int)
    case trades
    case tokenFyers
    case tokenKite
    case authFyers
    case startIronCondor
    case startScalping
    case startOptions
    case stop

    func url(baseURL: String) throws -> URL {
        let base = baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path: String
        switch self {
        case .health:            path = "/health"
        case .status:            path = "/status"
        case .logs(let n):       path = "/logs?lines=\(n)"
        case .trades:            path = "/trades"
        case .tokenFyers:        path = "/token/fyers"
        case .tokenKite:         path = "/token/kite"
        case .authFyers:         path = "/auth/fyers"
        case .startIronCondor:   path = "/start/iron-condor"
        case .startScalping:     path = "/start/scalping"
        case .startOptions:      path = "/start/options"
        case .stop:              path = "/stop"
        }
        guard let url = URL(string: base + path) else {
            throw APIError.unreachable(base)
        }
        return url
    }
}
