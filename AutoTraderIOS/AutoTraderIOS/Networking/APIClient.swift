import Foundation
import os.log

struct APIClient {
    let baseURL: String
    /// X-API-Key sent on every request. Empty string == not configured.
    var apiKey: String = ""
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

    // MARK: - Start Simple Engine

    func startEngine(name: String, dryRun: Bool) async throws -> StartResponse {
        Self.logger.debug("→ POST /start/\(name) dryRun=\(dryRun)")
        var req = try urlRequest("/start/\(name)", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["dry_run": dryRun])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StartResponse.self, from: data)
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

    // MARK: - v2 Engines

    func launchEngine(_ req: LaunchRequest) async throws -> LaunchResponse {
        Self.logger.debug("→ POST /api/v2/engines/launch")
        var urlReq = try urlRequest("/api/v2/engines/launch", method: "POST", timeout: Self.actionTimeout)
        urlReq.httpBody = try JSONEncoder().encode(req)
        let (data, response) = try await perform(urlReq)
        try validate(response, data: data)
        return try decode(LaunchResponse.self, from: data)
    }

    func stopEngine(id: String) async throws -> StopResponse {
        Self.logger.debug("→ POST /api/v2/engines/\(id)/stop")
        var req = try urlRequest("/api/v2/engines/\(id)/stop", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StopResponse.self, from: data)
    }

    func engines() async throws -> [EngineHeartbeat] {
        Self.logger.debug("→ GET /api/v1/engines")
        let (data, response) = try await fetch("/api/v1/engines", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(EnginesResponse.self, from: data).engines
    }

    // MARK: - Health (deep)

    func healthDeep() async throws -> HealthDeepResponse {
        Self.logger.debug("→ GET /health/deep")
        let (data, response) = try await fetch("/health/deep", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(HealthDeepResponse.self, from: data)
    }

    // MARK: - Broker health

    func brokerHealth() async throws -> BrokerHealthResponse {
        Self.logger.debug("→ GET /api/v2/broker-health")
        let (data, response) = try await fetch("/api/v2/broker-health", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(BrokerHealthResponse.self, from: data)
    }

    // MARK: - Logs (files / broker API)

    func brokerApiLog(lines: Int = 100) async throws -> LogsResponse {
        Self.logger.debug("→ GET /logs/api?lines=\(lines)")
        let url = try queryURL("/logs/api", [URLQueryItem(name: "lines", value: String(lines))])
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogsResponse.self, from: data)
    }

    func logFiles() async throws -> LogFilesResponse {
        Self.logger.debug("→ GET /logs/files")
        let (data, response) = try await fetch("/logs/files", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogFilesResponse.self, from: data)
    }

    func logFile(name: String, lines: Int = 300) async throws -> LogFileResponse {
        Self.logger.debug("→ GET /logs/file?name=\(name)")
        let url = try queryURL("/logs/file", [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "lines", value: String(lines)),
        ])
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogFileResponse.self, from: data)
    }

    // MARK: - Alerts

    func alerts() async throws -> [Alert] {
        Self.logger.debug("→ GET /api/v2/alerts")
        let (data, response) = try await fetch("/api/v2/alerts", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(AlertsResponse.self, from: data).alerts
    }

    // MARK: - API key rotation

    func rotateApiKey(newKey: String) async throws {
        Self.logger.debug("→ PUT /api/v1/config/api-key")
        var req = try urlRequest("/api/v1/config/api-key", method: "PUT", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["api_key": newKey])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
    }

    // MARK: - Auth URL

    func fyersAuthURL() throws -> URL {
        try authURL(broker: "fyers")
    }

    func authURL(broker: String) throws -> URL {
        guard let url = URL(string: baseURL + "/auth/\(broker)") else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return url
    }

    /// Tradesmart exchanges an auth code (not a bare access token).
    func exchangeTradesmart(authCode: String) async throws -> TokenResponse {
        Self.logger.debug("→ POST /token/tradesmart/exchange")
        var req = try urlRequest("/token/tradesmart/exchange", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(["auth_code": authCode])
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(TokenResponse.self, from: data)
    }

    // MARK: - Private

    private func fetch(_ path: String, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        return try await performURL(url, timeout: timeout)
    }

    private func queryURL(_ path: String, _ items: [URLQueryItem]) throws -> URL {
        guard var comps = URLComponents(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        return url
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
        var request = request
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
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
        case 401:
            Self.logger.error("✗ Unauthorized — bad or missing API key")
            throw APIError.unauthorized
        case 503:
            var detail = ""
            if let data {
                struct StringDetail: Decodable { let detail: String }
                detail = (try? Self.decoder.decode(StringDetail.self, from: data))?.detail ?? ""
            }
            if detail.localizedCaseInsensitiveContains("API_KEY") {
                Self.logger.error("✗ Server API key not configured")
                throw APIError.serverKeyNotConfigured
            }
            throw APIError.httpError(statusCode: 503, detail: detail)
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
