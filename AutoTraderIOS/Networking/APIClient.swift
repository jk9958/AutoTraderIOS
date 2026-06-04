import Foundation

@MainActor
final class APIClient: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "serverBaseURL")
        }
    }

    private let actionTimeout: TimeInterval = 10
    private let pollTimeout: TimeInterval = 6

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "serverBaseURL") ?? "http://100.124.30.59:8000"
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        endpoint: Endpoint,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let url = try endpoint.url(baseURL: baseURL)
        var request = URLRequest(url: url, timeoutInterval: timeout ?? actionTimeout)
        request.httpMethod = method
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw APIError.timeout(baseURL)
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet,
                 .cannotFindHost, .dnsLookupFailed:
                throw APIError.unreachable(baseURL)
            default:
                throw APIError.unreachable(baseURL)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid response")
        }

        if httpResponse.statusCode == 409 {
            let detail = extractStringDetail(from: data) ?? "Engine already running. POST /stop first."
            throw APIError.conflict(detail)
        }

        if httpResponse.statusCode == 422 {
            if let errors = extractValidationErrors(from: data) {
                throw APIError.validationErrors(errors)
            }
            throw APIError.httpError(422, "Validation failed")
        }

        if httpResponse.statusCode >= 500 {
            throw APIError.serverError("The server hit an error. Check the server logs.")
        }

        if httpResponse.statusCode >= 400 {
            let detail = extractStringDetail(from: data) ?? "Request failed."
            throw APIError.httpError(httpResponse.statusCode, detail)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Health

    func checkHealth() async throws {
        let _: HealthResponse = try await request(endpoint: .health)
    }

    // MARK: - Status

    func fetchStatus() async throws -> ServerStatus {
        return try await request(endpoint: .status, timeout: pollTimeout)
    }

    // MARK: - Logs

    func fetchLogs(lines: Int) async throws -> LogsResponse {
        return try await request(endpoint: .logs(lines: lines), timeout: pollTimeout)
    }

    // MARK: - Trades

    func fetchTrades() async throws -> TradesResponse {
        return try await request(endpoint: .trades, timeout: pollTimeout)
    }

    // MARK: - Token

    func postToken(broker: String, accessToken: String) async throws -> TokenResponse {
        let endpoint: Endpoint = broker == "fyers" ? .tokenFyers : .tokenKite
        return try await request(endpoint: endpoint, method: "POST", body: ["access_token": accessToken])
    }

    // MARK: - Start

    func startIronCondor(params: IronCondorParams) async throws -> StartResponse {
        return try await request(
            endpoint: .startIronCondor,
            method: "POST",
            body: params.toRequestBody()
        )
    }

    func startScalping(dryRun: Bool) async throws -> StartResponse {
        return try await request(
            endpoint: .startScalping,
            method: "POST",
            body: ["dry_run": dryRun]
        )
    }

    func startOptions(dryRun: Bool) async throws -> StartResponse {
        return try await request(
            endpoint: .startOptions,
            method: "POST",
            body: ["dry_run": dryRun]
        )
    }

    // MARK: - Stop

    func stopEngine() async throws -> StopResponse {
        return try await request(endpoint: .stop, method: "POST")
    }

    // MARK: - OAuth URL

    func fyersAuthURL() throws -> URL {
        return try Endpoint.authFyers.url(baseURL: baseURL)
    }

    // MARK: - Helpers

    private func extractStringDetail(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = json["detail"] as? String {
            return detail
        }
        return nil
    }

    private func extractValidationErrors(from data: Data) -> [APIErrorDetail]? {
        struct ErrorBody: Codable {
            let detail: [APIErrorDetail]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let body = try? decoder.decode(ErrorBody.self, from: data) {
            return body.detail
        }
        return nil
    }
}

// Minimal helper response models
private struct HealthResponse: Codable {
    let status: String
}

struct StopResponse: Codable {
    let status: String
    let engine: String?
}
