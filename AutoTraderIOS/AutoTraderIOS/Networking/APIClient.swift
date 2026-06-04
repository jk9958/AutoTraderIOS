import Foundation
import os.log

struct APIClient {
    let baseURL: String
    /// Mobile API v1 write key, sent as `X-API-Key`. Nil/empty on read-only use.
    var apiKey: String?
    private static let logger = Logger(subsystem: "com.autotrader.ios", category: "API")

    private static let pollTimeout: TimeInterval = 60
    private static let actionTimeout: TimeInterval = 60

    /// One shared session for connection reuse. Ephemeral: no on-disk caching of
    /// responses (which can carry config/token material) and, crucially, NO custom
    /// trust delegate — the system performs full TLS certificate validation against
    /// the public cert. Never bypass this. Per-request timeouts come from each
    /// `URLRequest`.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = pollTimeout
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

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
        try await withRetry {
            Self.logger.debug("→ GET /status")
            let (data, response) = try await fetch("/status", timeout: Self.pollTimeout)
            try validate(response, data: data)
            return try decode(ServerStatus.self, from: data)
        }
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
        try await withRetry {
            Self.logger.debug("→ GET /mtm")
            let (data, response) = try await fetch("/mtm", timeout: Self.pollTimeout)
            try validate(response, data: data)
            return try decode(MTMResponse.self, from: data)
        }
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

    // MARK: - Diagnostics & extra monitoring

    /// GET /health/deep — component-level system check (never 500s server-side).
    func healthDeep() async throws -> HealthDeepResponse {
        try await withRetry {
            Self.logger.debug("→ GET /health/deep")
            let (data, response) = try await fetch("/health/deep", timeout: Self.pollTimeout)
            try validate(response, data: data)
            return try decode(HealthDeepResponse.self, from: data)
        }
    }

    /// GET /metrics/app — free-form in-process counters/latency summary.
    func appMetrics() async throws -> JSONValue {
        Self.logger.debug("→ GET /metrics/app")
        let (data, response) = try await fetch("/metrics/app", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(JSONValue.self, from: data)
    }

    /// GET /scalping/mtm — live P&L for the VIX scalp loop (null when flat).
    func scalpingMTM() async throws -> ScalpingMTMResponse {
        Self.logger.debug("→ GET /scalping/mtm")
        let (data, response) = try await fetch("/scalping/mtm", timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(ScalpingMTMResponse.self, from: data)
    }

    /// POST /stop/vix-scalp — stop only the scalp loop.
    func stopVixScalp() async throws -> StopResponse {
        Self.logger.debug("→ POST /stop/vix-scalp")
        var req = try urlRequest("/stop/vix-scalp", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(StopResponse.self, from: data)
    }

    /// GET /logs/vix — VIX scalp logs.
    func vixLogs(lines: Int = 200) async throws -> LogsResponse {
        let url = try makeURL("/logs/vix", query: [URLQueryItem(name: "lines", value: String(lines))])
        Self.logger.debug("→ GET /logs/vix?lines=\(lines)")
        let (data, response) = try await performURL(url, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(LogsResponse.self, from: data)
    }

    // MARK: - Mobile API v1 — multi-engine management

    /// GET /api/v1/engines — open (no key).
    func listEngines() async throws -> EnginesListResponse {
        try await withRetry {
            Self.logger.debug("→ GET /api/v1/engines")
            let (data, response) = try await fetch("/api/v1/engines", timeout: Self.pollTimeout)
            try validate(response, data: data)
            return try decode(EnginesListResponse.self, from: data)
        }
    }

    /// GET /api/v1/engines/{id}/status — open.
    func engineStatus(_ engineId: String) async throws -> EngineStatusResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))/status"
        Self.logger.debug("→ GET \(path)")
        let (data, response) = try await fetch(path, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(EngineStatusResponse.self, from: data)
    }

    /// GET /api/v1/engines/{id}/config — open.
    func engineConfig(_ engineId: String) async throws -> EngineConfigResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))/config"
        Self.logger.debug("→ GET \(path)")
        let (data, response) = try await fetch(path, timeout: Self.pollTimeout)
        try validate(response, data: data)
        return try decode(EngineConfigResponse.self, from: data)
    }

    /// POST /api/v1/engines — requires X-API-Key.
    func createEngine(_ body: CreateEngineRequest) async throws -> EngineActionResponse {
        Self.logger.debug("→ POST /api/v1/engines (\(body.engineId))")
        var req = try urlRequest("/api/v1/engines", method: "POST", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(EngineActionResponse.self, from: data)
    }

    /// PATCH /api/v1/engines/{id}/config — requires X-API-Key.
    func patchEngineConfig(_ engineId: String, body: PatchEngineConfigRequest) async throws -> EngineConfigResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))/config"
        Self.logger.debug("→ PATCH \(path)")
        var req = try urlRequest(path, method: "PATCH", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(EngineConfigResponse.self, from: data)
    }

    /// POST /api/v1/engines/{id}/{start|stop|restart} — requires X-API-Key.
    func engineLifecycle(_ engineId: String, action: EngineLifecycleAction) async throws -> EngineActionResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))/\(action.rawValue)"
        Self.logger.debug("→ POST \(path)")
        var req = try urlRequest(path, method: "POST", timeout: Self.actionTimeout)
        req.httpBody = Data()
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(EngineActionResponse.self, from: data)
    }

    /// DELETE /api/v1/engines/{id} — requires X-API-Key. Secrets preserved server-side.
    func deleteEngine(_ engineId: String) async throws -> EngineActionResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))"
        Self.logger.debug("→ DELETE \(path)")
        let req = try urlRequest(path, method: "DELETE", timeout: Self.actionTimeout)
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(EngineActionResponse.self, from: data)
    }

    /// PUT /api/v1/engines/{id}/token — requires X-API-Key.
    func updateEngineToken(_ engineId: String, accessToken: String) async throws -> EngineActionResponse {
        let path = "/api/v1/engines/\(Self.escape(engineId))/token"
        Self.logger.debug("→ PUT \(path)")
        var req = try urlRequest(path, method: "PUT", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(EngineTokenRequest(accessToken: accessToken))
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(EngineActionResponse.self, from: data)
    }

    /// PUT /api/v1/config/api-key — rotate. Authenticate with the CURRENT key.
    func rotateApiKey(newKey: String) async throws -> RotateKeyResponse {
        Self.logger.debug("→ PUT /api/v1/config/api-key")
        var req = try urlRequest("/api/v1/config/api-key", method: "PUT", timeout: Self.actionTimeout)
        req.httpBody = try JSONEncoder().encode(RotateKeyRequest(apiKey: newKey))
        let (data, response) = try await perform(req)
        try validate(response, data: data)
        return try decode(RotateKeyResponse.self, from: data)
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
        applyAPIKey(&req)
        return try await perform(req)
    }

    private func urlRequest(_ path: String, method: String, timeout: TimeInterval) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAPIKey(&req)
        return req
    }

    /// Attach the mobile-API write key when present. Harmless on read endpoints.
    private func applyAPIKey(_ req: inout URLRequest) {
        if let key = apiKey, !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
    }

    /// Build a GET URL with query items against the base URL.
    private func makeURL(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var comps = URLComponents(string: baseURL + path) else {
            throw APIError.wrongBaseURL(url: baseURL)
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw APIError.wrongBaseURL(url: baseURL) }
        return url
    }

    /// Percent-encode an engine_id for safe path interpolation.
    private static func escape(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component
    }

    /// Retry an **idempotent** operation on transient failures (no network, timeout,
    /// 5xx) with exponential backoff (0.5s → 1s → 2s). Never use for writes.
    /// Cancellation breaks out immediately (the sleep throws).
    private func withRetry<T>(maxAttempts: Int = 3, _ op: () async throws -> T) async throws -> T {
        var attempt = 0
        var delay: UInt64 = 500_000_000
        while true {
            do {
                return try await op()
            } catch let error as APIError where Self.isTransient(error) {
                attempt += 1
                if attempt >= maxAttempts { throw error }
                try await Task.sleep(nanoseconds: delay)
                delay *= 2
            }
        }
    }

    private static func isTransient(_ error: APIError) -> Bool {
        switch error {
        case .noNetwork, .timeout, .serverUnreachable: return true
        case .httpError(let code, _): return code >= 500
        default: return false
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await Self.session.data(for: request)
            if let http = response as? HTTPURLResponse {
                // Status + size only. Never log bodies — responses can carry config
                // and token material.
                Self.logger.debug("← \(http.statusCode) \(request.url?.lastPathComponent ?? "?") (\(data.count) bytes)")
            }
            return (data, response)
        } catch let err as URLError {
            Self.logger.error("✗ Request failed: \(err.code.rawValue) - \(request.url?.lastPathComponent ?? "?")")
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.noNetwork
            case .cannotConnectToHost, .resourceUnavailable:
                // Host is reachable but refused/dropped the connection — usually a
                // backend restart. Transient, so this gets retried.
                throw APIError.serverUnreachable
            case .cannotFindHost, .dnsLookupFailed:
                // Name doesn't resolve — a genuine wrong-address problem.
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

        // Decode the FastAPI `{detail: "..."}` string once for the cases that use it.
        func detailString() -> String {
            guard let data else { return "" }
            struct StringDetail: Decodable { let detail: String }
            return (try? Self.decoder.decode(StringDetail.self, from: data))?.detail ?? ""
        }

        switch http.statusCode {
        case 401:
            Self.logger.error("✗ Unauthorized (X-API-Key)")
            throw APIError.unauthorized
        case 503:
            let detail = detailString()
            Self.logger.error("✗ 503: \(detail)")
            // Only the missing-API-key case gets the dedicated message; other 503s
            // (restarts, proxy) are transient/retryable.
            if detail.localizedCaseInsensitiveContains("API_KEY") {
                throw APIError.serverKeyNotConfigured(detail: detail)
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
            let detail = detailString()
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

