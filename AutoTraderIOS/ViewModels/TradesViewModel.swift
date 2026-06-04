import SwiftUI

@MainActor
final class TradesViewModel: ObservableObject {
    @Published var trades: [[String: String]] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasLoaded: Bool = false

    func load(using apiClient: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await apiClient.fetchTrades()
            trades = response.trades.reversed()
            hasLoaded = true
            errorMessage = nil
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh(using apiClient: APIClient) async {
        await load(using: apiClient)
    }
}
