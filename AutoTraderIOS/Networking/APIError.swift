import Foundation

enum APIError: LocalizedError {
    case unreachable(String)
    case timeout(String)
    case httpError(Int, String)
    case conflict(String)               // 409
    case validationErrors([APIErrorDetail]) // 422
    case serverError(String)            // 5xx
    case decodingError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let url):
            return "Can't reach the server. Check that Tailscale is connected and the server is running. (\(url))"
        case .timeout:
            return "Server timed out. It may be starting up — try again."
        case .httpError(let code, let detail):
            if code >= 500 {
                return "The server hit an error. Check the server logs."
            }
            return detail.isEmpty ? "Request failed (HTTP \(code))." : detail
        case .conflict(let detail):
            return detail.isEmpty ? "An engine is already running. Stop it first." : detail
        case .validationErrors(let errors):
            return errors.map { $0.msg }.joined(separator: "\n")
        case .serverError(let msg):
            return msg
        case .decodingError(let msg):
            return "Response parsing failed: \(msg)"
        case .unknown(let msg):
            return msg
        }
    }

    var isTransport: Bool {
        switch self {
        case .unreachable, .timeout: return true
        default: return false
        }
    }

    var isConflict: Bool {
        if case .conflict = self { return true }
        return false
    }

    var validationErrors: [APIErrorDetail]? {
        if case .validationErrors(let errors) = self { return errors }
        return nil
    }
}
