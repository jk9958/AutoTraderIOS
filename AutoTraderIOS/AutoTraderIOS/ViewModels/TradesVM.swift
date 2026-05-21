import SwiftUI
import Combine


@MainActor
final class TradesVM: ObservableObject {
    @Published var trades: [[String: String]] = []
    @Published var isLoading = false
    @Published var error: String?

    func fetch(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await client.trades()
            trades = resp.trades.reversed()
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
