import SwiftUI
import Combine

@MainActor
final class LogsVM: ObservableObject {
    @Published var lines: [String] = []
    @Published var source: String = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var lineCount: Int = 200
    @Published var autoscroll = true

    private var pollingTask: Task<Void, Never>?

    func startPolling(client: APIClient) {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetch(client: client)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh(client: APIClient) {
        Task { await fetch(client: client) }
    }

    private func fetch(client: APIClient) async {
        if lines.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            let resp = try await client.logs(lines: lineCount)
            lines = resp.lines
            source = resp.source
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
