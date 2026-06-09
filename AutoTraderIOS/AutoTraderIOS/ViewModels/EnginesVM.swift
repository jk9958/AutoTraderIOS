import SwiftUI
import Combine

@MainActor
final class EnginesVM: ObservableObject {
    @Published var engines: [EngineHeartbeat] = []
    @Published var loadError: String?
    @Published var isLoading = false
    @Published var stoppingIds: Set<String> = []

    private var pollTask: Task<Void, Never>?

    // MARK: - Polling

    func start(appState: AppState) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.reload(appState: appState)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func reload(appState: AppState) async {
        if engines.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            engines = try await appState.client.engines()
            loadError = nil
        } catch let err as APIError {
            loadError = err.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Stop

    func stopEngine(_ engine: EngineHeartbeat, appState: AppState) async {
        stoppingIds.insert(engine.engineId)
        defer { stoppingIds.remove(engine.engineId) }
        do {
            _ = try await appState.client.stopEngine(id: engine.engineId)
            Haptics.success()
            await reload(appState: appState)
        } catch let err as APIError {
            loadError = err.errorDescription
            Haptics.error()
        } catch {
            loadError = error.localizedDescription
            Haptics.error()
        }
    }
}
