import Foundation
import os.log

struct APIClient {
    let baseURL: String
    private static let logger = Logger(subsystem: "com.autotrader.ios", category: "API")

    private static let pollTimeout: TimeInterval = 60
    private static let actionTimeout: TimeInterval = 60

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = pollTimeout
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: TrustDelegate(), delegateQueue: nil)
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Health

    func health() async throws {
        Self.logger.debug("→ GET /health")
        let (_, response) = try await fetch("/health", timeout: Self.pollTimeout)
        try validate(response)
    }

    // MARK: - Status

    func status() async throws -> ServerStatus {
        Self.logger.debug("→ GET /status")
        let (data, response) = try await fetch("/status", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(ServerStatus.self, from: data)
    }

    // MARK: - Logs

    func logs(lines: Int = 200) async throws -> LogsResponse {
        Self.logger.debug("→ GET /logs?lines=\(lines)")
        guard var comps = URLComponents(string: baseURL + "/logs") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = [URLQueryItem(name: "lines", value: String(lines))]
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogsResponse.self, from: data)
    }

    // MARK: - Trades

    func trades() async throws -> TradesResponse {
        Self.logger.debug("→ GET /trades")
        let (data, response) = try await fetch("/trades", timeout: Self.actionTimeout)
        try validate(response, data: data)
        return try decode(TradesResponse.self, from: data)
    }

    // MARK: - MTM

    func mtm() async throws -> MTMResponse {
        Self.logger.debug("→ GET /mtm")
        let (data, response) = try await fetch("/mtm", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(MTMResponse.self, from: data)
    }

    // MARK: - Token

    func setToken(broker: String, accessToken: String) async throws -> TokenResponse {
        Self.logger.debug("→ POST /token/\(broker)")
        var req = try urlRequest("/token/\(broker)", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["access_token": accessToken])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(TokenResponse.self, from: data)
    }

    // MARK: - Start Iron Condor

    func startIronCondor(_ params: IronCondorParams) async throws -> StartResponse {
        Self.logger.debug("→ POST /start/iron-condor")
        var req = try urlRequest("/start/iron-condor", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(params)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StartResponse.self, from: data)
    }

    // MARK: - Start VIX Scalp

    func startVixScalp(_ params: VixScalpParams) async throws -> StartResponse {
        Self.logger.debug("→ POST /start/vix-scalp")
        var req = try urlRequest("/start/vix-scalp", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(params)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StartResponse.self, from: data)
    }

    // MARK: - Start Simple Engine

    func startEngine(name: String, dryRun: Bool) async throws -> StartResponse {
        Self.logger.debug("→ POST /start/\(name) dryRun=\(dryRun)")
        var req = try urlRequest("/start/\(name)", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["dry_run": dryRun])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StartResponse.self, from: data)
    }

    // MARK: - Trend Agent

    func startTrendAgent(_ params: TrendAgentParams) async throws -> StartResponse {
        Self.logger.debug("→ POST /start/trend-agent")
        var req = try urlRequest("/start/trend-agent", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(params)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StartResponse.self, from: data)
    }

    func stopTrendAgent() async throws -> StopResponse {
        Self.logger.debug("→ POST /stop/trend-agent")
        var req = try urlRequest("/stop/trend-agent", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StopResponse.self, from: data)
    }

    func trendAgentStatus() async throws -> TrendAgentStatus {
        Self.logger.debug("→ GET /trend-agent/status")
        let (data, response) = try await fetch("/trend-agent/status", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(TrendAgentStatus.self, from: data)
    }

    func trendAgentSignals() async throws -> TrendSignals {
        Self.logger.debug("→ GET /trend-agent/signals")
        let (data, response) = try await fetch("/trend-agent/signals", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(TrendSignals.self, from: data)
    }

    func trendAgentLearning() async throws -> TrendLearning {
        Self.logger.debug("→ GET /trend-agent/learning")
        let (data, response) = try await fetch("/trend-agent/learning", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(TrendLearning.self, from: data)
    }

    func trendAgentTrades() async throws -> TrendTradesResponse {
        Self.logger.debug("→ GET /trend-agent/trades")
        let (data, response) = try await fetch("/trend-agent/trades", timeout: Self.actionTimeout)
        try validate(response, data: data)
        return try decode(TrendTradesResponse.self, from: data)
    }

    func trendAgentLogs(lines: Int = 200) async throws -> LogsResponse {
        Self.logger.debug("→ GET /trend-agent/logs?lines=\(lines)")
        guard var comps = URLComponents(string: baseURL + "/trend-agent/logs") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = [URLQueryItem(name: "lines", value: String(lines))]
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogsResponse.self, from: data)
    }

    // MARK: - Stop

    func stop() async throws -> StopResponse {
        Self.logger.debug("→ POST /stop")
        var req = try urlRequest("/stop", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StopResponse.self, from: data)
    }

    // MARK: - Margin Estimator

    func ironCondorMargin(instrument: String, lots: Int, spreadPts: Int, wingPts: Int, expiry: String) async throws -> MarginResponse {
        Self.logger.debug("→ GET /margin/iron-condor")
        guard var comps = URLComponents(string: baseURL + "/margin/iron-condor") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = [
            URLQueryItem(name: "instrument", value: instrument),
            URLQueryItem(name: "lots",       value: String(lots)),
            URLQueryItem(name: "spread_pts", value: String(spreadPts)),
            URLQueryItem(name: "wing_pts",   value: String(wingPts)),
            URLQueryItem(name: "expiry",     value: expiry),
        ]
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        let (data, response) = try await performURL(url, timeout: Self.actionTimeout)
        try validate(response, data: data)
        return try decode(MarginResponse.self, from: data)
    }

    // MARK: - Save Fyers Token to .env

    func saveFyersTokenToEnv() async throws -> MessageResponse {
        Self.logger.debug("→ POST /token/fyers/save-env")
        var req = try urlRequest("/token/fyers/save-env", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(MessageResponse.self, from: data)
    }

    // MARK: - TradeSmart Token Exchange

    func exchangeTradesmartToken(requestToken: String) async throws -> TokenResponse {
        Self.logger.debug("→ POST /token/tradesmart/exchange")
        var req = try urlRequest("/token/tradesmart/exchange", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["code": requestToken])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(TokenResponse.self, from: data)
    }

    // MARK: - Clear Logs

    func clearLogs() async throws {
        Self.logger.debug("→ POST /logs/clear")
        var req = try urlRequest("/logs/clear", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (_, response) = try await perform(req)
        try validate(response)
    }

    // MARK: - API Logs

    func apiLogs(lines: Int = 200) async throws -> LogsResponse {
        Self.logger.debug("→ GET /logs/api?lines=\(lines)")
        guard var comps = URLComponents(string: baseURL + "/logs/api") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = [URLQueryItem(name: "lines", value: String(lines))]
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogsResponse.self, from: data)
    }

    // MARK: - Metrics

    func metrics(window: Int = 12) async throws -> MetricsResponse {
        Self.logger.debug("→ GET /metrics?window=\(window)")
        guard var comps = URLComponents(string: baseURL + "/metrics") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = [URLQueryItem(name: "window", value: String(window))]
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(MetricsResponse.self, from: data)
    }

    // MARK: - Auth URLs

    func fyersAuthURL() throws -> URL {
        guard let url = URL(string: baseURL + "/auth/fyers") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return url
    }

    func tradesmartAuthURL() throws -> URL {
        guard let url = URL(string: baseURL + "/auth/tradesmart") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return url
    }

    func kiteAuthURL() throws -> URL {
        guard let url = URL(string: baseURL + "/auth/kite") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return url
    }

    // MARK: - Private

    private func fetch(_ path: String, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return try await performURL(url, timeout: timeout)
    }

    private func performURL(_ url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(req)
    }

    private func urlRequest(_ path: String, method: String, timeout: TimeInterval) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let session = Self.makeSession()
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                Self.logger.debug("← \(http.statusCode) \(request.url?.lastPathComponent ?? "?")")
            }
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                Self.logger.debug("← body: \(body)")
            }
            #endif
            return (data, response)
        } catch let err as URLError {
            Self.logger.error("✗ Request failed: \(err.code.rawValue) - \(request.url?.lastPathComponent ?? "?")")
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.noNetwork
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw APIError.wrongBaseURL(url: request.url?.absoluteString ?? baseURL)
            case .timedOut:
                throw APIError.timeout(url: request.url?.absoluteString ?? baseURL)
            case .unsupportedURL, .badURL:
                throw APIError.wrongBaseURL(url: request.url?.absoluteString ?? baseURL)
            default:
                throw APIError.noNetwork
            }
        }
    }

    private func validate(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard !(200...299).contains(http.statusCode) else { return }

        switch http.statusCode {
        case 409:
            Self.logger.error("✗ Engine already running")
            throw APIError.engineAlreadyRunning
        case 422:
            if let data {
                struct Wrapper: Decodable { let detail: [ValidationErrorItem] }
                if let w = try? Self.decoder.decode(Wrapper.self, from: data) {
                    Self.logger.error("✗ Validation error: \(w.detail.map { $0.msg }.joined(separator: ", "))")
                    throw APIError.validationError(messages: w.detail.map { $0.msg })
                }
            }
            Self.logger.error("✗ Validation failed")
            throw APIError.validationError(messages: ["Validation failed — check form fields."])
        default:
            var detail = ""
            if let data {
                struct StringDetail: Decodable { let detail: String }
                detail = (try? Self.decoder.decode(StringDetail.self, from: data))?.detail ?? ""
            }
            Self.logger.error("✗ HTTP \(http.statusCode): \(detail)")
            throw APIError.httpError(statusCode: http.statusCode, detail: detail)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            let result = try Self.decoder.decode(type, from: data)
            Self.logger.debug("✓ Decoded \(String(describing: type))")
            return result
        } catch {
            Self.logger.error("✗ Failed to decode \(String(describing: type)): \(error)")
            throw APIError.decodingError
        }
    }
}

private class TrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
