import SwiftUI
import Combine

/// Single source of truth for the bot (engine) list, shared by Home, Bots and any
/// other screen so they never disagree. Owned by `AppState`; polls while the app
/// is foregrounded. Also tracks each running bot's real Practice/Live mode
/// (`params.dry_run`) so the UI never has to guess.
@MainActor
final class EnginesStore: ObservableObject {
    @Published private(set) var state: Loadable<[EngineInfo]> = .idle
    @Published private(set) var busy: Set<String> = []
    /// engineId → dry_run (true = Practice, false = Live). Absent = unknown.
    @Published private(set) var modes: [String: Bool] = [:]
    @Published var banner: String?

    /// Resolves the current service each call so base-URL / API-key changes are picked up.
    private let service: () -> EngineServicing
    private var pollTask: Task<Void, Never>?

    init(service: @escaping () -> EngineServicing) { self.service = service }

    var engines: [EngineInfo] { state.value ?? [] }
    func mode(for id: String) -> Bool? { modes[id] }

    // MARK: Polling (app-scoped)

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: Loading

    func refresh(showSpinner: Bool = false) async {
        if showSpinner, state.value == nil { state = .loading }
        do {
            let resp = try await service().listEngines()
            if Task.isCancelled { return }
            if !resp.ok, let err = resp.error {
                if state.value == nil { state = .failed(err) } else { banner = err }
                return
            }
            state = .loaded(resp.engines)
            await refreshModes(for: resp.engines)
        } catch is CancellationError {
            return
        } catch {
            let fe = FriendlyError.from(error)
            if state.value == nil { state = .failed(fe.message) } else { banner = fe.message }
        }
    }

    /// Fetch real `dry_run` for running bots whose mode we don't yet know. Mode only
    /// changes after a restart (which invalidates it), so this won't storm the server.
    private func refreshModes(for engines: [EngineInfo]) async {
        let ids = Set(engines.map(\.engineId))
        modes = modes.filter { ids.contains($0.key) }   // prune deleted bots
        for e in engines where e.runState == .running && modes[e.engineId] == nil {
            if let cfg = try? await service().engineConfig(e.engineId).config,
               let dry = cfg.dryRunFlag {
                modes[e.engineId] = dry
            }
        }
    }

    // MARK: Mutations (route through the store so every screen updates)

    func perform(_ action: EngineLifecycleAction, on id: String) async {
        guard !busy.contains(id) else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            _ = try await service().engineLifecycle(id, action: action)
            modes[id] = nil                 // mode may change after start/restart
            Haptics.success()
            await refresh()
        } catch {
            banner = FriendlyError.from(error).message
            Haptics.error()
        }
    }

    func delete(_ id: String) async {
        guard !busy.contains(id) else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            _ = try await service().deleteEngine(id)
            modes[id] = nil
            Haptics.success()
            await refresh()
        } catch {
            banner = FriendlyError.from(error).message
            Haptics.error()
        }
    }

    /// Call after an external change (e.g. detail-screen PATCH or token update) so
    /// the shared list and mode cache re-sync.
    func invalidate(_ id: String) {
        modes[id] = nil
        Task { await refresh() }
    }
}
