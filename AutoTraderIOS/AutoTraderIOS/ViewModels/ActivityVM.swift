import SwiftUI
import Combine

/// Backs the Activity tab: open positions (P&L), trade history, and a simple
/// performance summary. Each source loads best-effort so one failure doesn't
/// blank the others.
@MainActor
final class ActivityVM: ObservableObject {
    @Published var mtm: MTMData?
    @Published var scalpHasPositions = false
    @Published var marketOpen: Bool?
    @Published var trades: [[String: String]] = []
    @Published var metrics: MetricsResponse?
    @Published var isLoading = false
    @Published var error: FriendlyError?

    func load(client: APIClient) async {
        if mtm == nil && trades.isEmpty { isLoading = true }
        defer { isLoading = false }

        async let mtmTask: Void = loadMTM(client: client)
        async let tradesTask: Void = loadTrades(client: client)
        async let scalpTask: Void = loadScalp(client: client)
        async let metricsTask: Void = loadMetrics(client: client)
        _ = await (mtmTask, tradesTask, scalpTask, metricsTask)
    }

    private func loadMTM(client: APIClient) async {
        do {
            let resp = try await client.mtm()
            mtm = resp.mtm
            marketOpen = resp.marketOpen
            error = nil
        } catch { if mtm == nil { self.error = FriendlyError.from(error) } }
    }

    private func loadTrades(client: APIClient) async {
        do {
            let resp = try await client.trades()
            trades = resp.trades.map { row in
                var out: [String: String] = [:]
                for (k, v) in row { out[k] = v.stringValue }
                return out
            }.reversed()
        } catch { /* keep last known */ }
    }

    private func loadScalp(client: APIClient) async {
        do { scalpHasPositions = try await client.scalpingMTM().hasOpenPositions }
        catch { scalpHasPositions = false }
    }

    private func loadMetrics(client: APIClient) async {
        do { metrics = try await client.metrics() } catch { /* non-critical */ }
    }
}
