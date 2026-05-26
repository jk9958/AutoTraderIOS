import SwiftUI
import Combine


@MainActor
final class TradesVM: ObservableObject {
    @Published var mtm: MTMData?
    @Published var trades: [[String: String]] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var mtmRefreshTimer: Timer?

    func fetch(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let tradesResp = client.trades()
            async let mtmResp = client.mtm()

            let trades = try await tradesResp
            let mtm = try await mtmResp

            self.mtm = mtm.mtm
            self.trades = trades.trades.map { trade in
                var converted: [String: String] = [:]
                for (key, value) in trade {
                    converted[key] = value.stringValue
                }
                return converted
            }.reversed()
            error = nil

            startMTMRefresh(client: client)
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startMTMRefresh(client: APIClient) {
        stopMTMRefresh()
        mtmRefreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshMTM(client: client)
            }
        }
    }

    private func stopMTMRefresh() {
        mtmRefreshTimer?.invalidate()
        mtmRefreshTimer = nil
    }

    private func refreshMTM(client: APIClient) async {
        do {
            let resp = try await client.mtm()
            self.mtm = resp.mtm
        } catch {
            // Silent failure for refresh
        }
    }

    deinit {
        stopMTMRefresh()
    }
}
