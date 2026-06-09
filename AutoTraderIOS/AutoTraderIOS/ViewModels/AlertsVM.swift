import SwiftUI
import Combine

@MainActor
final class AlertsVM: ObservableObject {
    @Published var alerts: [Alert] = []
    @Published var error: String?
    @Published var isLoading = false

    private var pollTask: Task<Void, Never>?

    func start(appState: AppState) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.reload(appState: appState)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func reload(appState: AppState) async {
        if alerts.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            alerts = try await appState.client.alerts()
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
