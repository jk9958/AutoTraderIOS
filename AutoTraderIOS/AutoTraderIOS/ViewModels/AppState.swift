import SwiftUI
import Combine

enum ConnectionState {
    case unknown, connected, disconnected
}

@MainActor
final class AppState: ObservableObject {

    @Published var serverStatus: ServerStatus?
    @Published var connectionState: ConnectionState = .unknown
    @Published var connectionError: String?

    @Published var serverBaseURL: String {
        didSet {
            let sanitized = Self.sanitizeURL(serverBaseURL)
            if sanitized != serverBaseURL { serverBaseURL = sanitized; return }
            UserDefaults.standard.set(serverBaseURL, forKey: "serverBaseURL")
            rebuildClient()
        }
    }

    /// X-API-Key, stored in the Keychain (never UserDefaults).
    @Published var apiKey: String {
        didSet {
            KeychainHelper.apiKey = apiKey
            rebuildClient()
        }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }
    var maskedAPIKey: String { KeychainHelper.masked(apiKey) }

    private func rebuildClient() {
        var c = APIClient(baseURL: serverBaseURL)
        c.apiKey = apiKey
        client = c
    }

    private static func sanitizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
        return "https://" + trimmed
    }

    @Published private(set) var client: APIClient

    private var pollingTask: Task<Void, Never>?
    private var isFirstPollFailure = true

    init() {
        let stored = UserDefaults.standard.string(forKey: "serverBaseURL") ?? ""
        let url = stored.isEmpty ? "https://trader.allweatheralgo.com" : Self.sanitizeURL(stored)
        let key = KeychainHelper.apiKey ?? ""
        self.serverBaseURL = url
        self.apiKey = key
        var c = APIClient(baseURL: url)
        c.apiKey = key
        self.client = c
        startLifecycleObservers()
    }

    // MARK: - Status

    func fetchStatus() async {
        do {
            let status = try await client.status()
            serverStatus = status
            connectionState = .connected
            connectionError = nil
            isFirstPollFailure = true
        } catch let err as APIError {
            handleConnectionError(err)
        } catch {
            handleConnectionError(.unknown(error.localizedDescription))
        }
    }

    // MARK: - Polling

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchStatus()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshNow() {
        Task { await fetchStatus() }
    }

    // MARK: - Lifecycle

    private func startLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.startPolling() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopPolling() }
        }
    }

    private func handleConnectionError(_ err: APIError) {
        connectionState = .disconnected
        if isFirstPollFailure {
            connectionError = err.errorDescription
            isFirstPollFailure = false
        }
    }
}
