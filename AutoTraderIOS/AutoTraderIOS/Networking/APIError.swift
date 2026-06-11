import Foundation

enum APIError: LocalizedError {
    case noNetwork
    case timeout(url: String)
    case wrongBaseURL(url: String)
    case httpError(statusCode: Int, detail: String)
    case validationError(messages: [String])
    case engineAlreadyRunning
    case unauthorized
    case serverKeyNotConfigured
    case decodingError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "Can't reach the server. Check that Tailscale is connected and the server is running."
        case .timeout:
            return "Server timed out. It may be starting up — try again."
        case .wrongBaseURL(let url):
            return "No server at \(url). Check the address in Settings."
        case .httpError(let code, let detail):
            if code >= 500 { return "The server hit an error. Check the server logs." }
            return detail.isEmpty ? "Request failed (HTTP \(code))." : detail
        case .validationError(let msgs):
            return msgs.joined(separator: "\n")
        case .engineAlreadyRunning:
            return "An engine is already running. Stop it first."
        case .unauthorized:
            return "Unauthorized (401). The server requires a valid API key — set or fix it in Settings."
        case .serverKeyNotConfigured:
            return "The server has no API key configured. Set one with key rotation."
        case .decodingError:
            return "Received unexpected data from the server."
        case .unknown(let msg):
            return msg
        }
    }

    var isConnectionError: Bool {
        switch self {
        case .noNetwork, .timeout, .wrongBaseURL: return true
        default: return false
        }
    }
}
