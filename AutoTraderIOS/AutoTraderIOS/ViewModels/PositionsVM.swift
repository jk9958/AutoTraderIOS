import SwiftUI
import Combine

@MainActor
final class PositionsVM: ObservableObject {
    @Published var mtm: MTMData?
    @Published var error: String?
    @Published var isLoading = false

    private var pollTask: Task<Void, Never>?

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
        if mtm == nil { isLoading = true }
        defer { isLoading = false }
        do {
            mtm = try await appState.client.mtm().mtm
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    var hasPosition: Bool {
        guard let mtm else { return false }
        // Treat a present spot/strikes or non-flat status as an open position.
        if let s = mtm.status, s.lowercased().contains("no") { return false }
        return mtm.shortCe != nil || mtm.shortPe != nil || mtm.netCredit != nil
    }
}
