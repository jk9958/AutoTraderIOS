import SwiftUI
import Combine

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var lines: [String] = []
    @Published var source: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isPaused: Bool = false
    @Published var selectedLineCount: Int = 200
    @Published var hasLoaded: Bool = false

    private var pollingManager: PollingManager?

    let lineCountOptions = [50, 100, 200, 500]

    func startPolling(using apiClient: APIClient) {
        guard pollingManager == nil else { return }
        pollingManager = PollingManager(interval: 5.0) { [weak self] in
            await self?.pollLogs(using: apiClient)
        }
        pollingManager?.start()
    }

    func stopPolling() {
        pollingManager?.stop()
        pollingManager = nil
    }

    private func pollLogs(using apiClient: APIClient) async {
        guard !isPaused else { return }
        do {
            let response = try await apiClient.fetchLogs(lines: selectedLineCount)
            lines = response.lines
            source = response.source
            hasLoaded = true
            errorMessage = nil
        } catch {
            if !hasLoaded {
                if let apiError = error as? APIError {
                    errorMessage = apiError.errorDescription
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh(using apiClient: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await apiClient.fetchLogs(lines: selectedLineCount)
            lines = response.lines
            source = response.source
            hasLoaded = true
            errorMessage = nil
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func togglePause() {
        isPaused.toggle()
    }

    func changeLineCount(_ count: Int, using apiClient: APIClient) {
        selectedLineCount = count
        Task { await refresh(using: apiClient) }
    }
}
