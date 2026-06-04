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

    /// Single source of truth for the bot list, shared by all tabs.
    let enginesStore: EnginesStore

    private let networkMonitor = NetworkMonitor()
    private var monitorCancellable: AnyCancellable?
    private var storeCancellable: AnyCancellable?
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

        // The store resolves the latest client each call, so base-URL/key changes apply.
        var clientBox: () -> APIClient = { c }
        self.enginesStore = EnginesStore(service: { clientBox() })

        monitorCancellable = networkMonitor.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in self?.isOnline = online }
        // Re-emit when the shared store changes so views observing AppState refresh.
        storeCancellable = enginesStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
        // Now that self is fully initialized, point the store at the live client.
        clientBox = { [unowned self] in self.client }
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
        enginesStore.startPolling()
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchStatus()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        enginesStore.stopPolling()
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
