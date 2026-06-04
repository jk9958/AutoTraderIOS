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

    /// Mobile API v1 write key (X-API-Key), persisted in the Keychain — never UserDefaults.
    @Published var apiKey: String {
        didSet {
            guard apiKey != oldValue else { return }
            KeychainStore.set(apiKey, account: KeychainStore.apiKeyAccount)
            rebuildClient()
        }
    }

    /// True when a write key is present, gating destructive UI affordances.
    var hasAPIKey: Bool { !apiKey.isEmpty }

    private func rebuildClient() {
        var c = APIClient(baseURL: serverBaseURL)
        c.apiKey = apiKey.isEmpty ? nil : apiKey
        client = c
    }

    private static func sanitizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
        return "https://" + trimmed
    }

    @Published private(set) var client: APIClient

    /// Network reachability, mirrored from `NetworkMonitor` for views to observe.
    @Published private(set) var isOnline = true

    private let networkMonitor = NetworkMonitor()
    private var monitorCancellable: AnyCancellable?
    private var pollingTask: Task<Void, Never>?
    private var isFirstPollFailure = true

    init() {
        let stored = UserDefaults.standard.string(forKey: "serverBaseURL") ?? ""
        let url = stored.isEmpty ? "https://trader.allweatheralgo.com" : Self.sanitizeURL(stored)
        let key = KeychainStore.get(account: KeychainStore.apiKeyAccount) ?? ""
        self.serverBaseURL = url
        self.apiKey = key
        var c = APIClient(baseURL: url)
        c.apiKey = key.isEmpty ? nil : key
        self.client = c
        self.isOnline = networkMonitor.isOnline
        monitorCancellable = networkMonitor.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in self?.isOnline = online }
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
                try? await Task.sleep(for: .seconds(5))
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
