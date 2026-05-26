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
            trades = resp.trades.map { trade in
                var converted: [String: String] = [:]
                for (key, value) in trade {
                    converted[key] = value.stringValue
                }
                return converted
            }.reversed()
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
