import SwiftUI
import Combine

private enum Keys {
    static let symbols       = "ta_symbols"
    static let capital       = "ta_capital"
    static let riskPct       = "ta_risk_pct"
    static let minConfidence = "ta_min_confidence"
    static let scanInterval  = "ta_scan_interval"
    static let maxTrades     = "ta_max_trades"
    static let adaptive      = "ta_adaptive"
    static let dryRun        = "ta_dry_run"
}

@MainActor
final class TrendAgentVM: ObservableObject {
    // Launch form
    @Published var symbolNifty: Bool
    @Published var symbolBankNifty: Bool
    @Published var capital: Double
    @Published var riskPct: Double
    @Published var minConfidence: Double
    @Published var scanInterval: Int
    @Published var maxTrades: Int
    @Published var adaptive: Bool
    @Published var dryRun: Bool

    // Live data
    @Published var status: TrendAgentStatus?
    @Published var signals: TrendSignals?
    @Published var learning: TrendLearning?
    @Published var error: String?

    // Action state
    @Published var isLaunching = false
    @Published var isStopping = false
    @Published var launchError: String?
    @Published var launchSuccess: String?
    @Published var showLiveConfirmation = false

    private let defaults = UserDefaults.standard
    private var pollTask: Task<Void, Never>?

    var isRunning: Bool { status?.running ?? false }

    var selectedSymbols: [String] {
        var s: [String] = []
        if symbolNifty { s.append("NIFTY") }
        if symbolBankNifty { s.append("BANKNIFTY") }
        return s.isEmpty ? ["NIFTY"] : s
    }

    init() {
        let storedSymbols = defaults.stringArray(forKey: Keys.symbols) ?? ["NIFTY"]
        symbolNifty     = storedSymbols.contains("NIFTY")
        symbolBankNifty = storedSymbols.contains("BANKNIFTY")
        let cap         = defaults.double(forKey: Keys.capital)
        capital         = cap > 0 ? cap : 200_000
        let rp          = defaults.double(forKey: Keys.riskPct)
        riskPct         = rp > 0 ? rp : 1.5
        let mc          = defaults.double(forKey: Keys.minConfidence)
        minConfidence   = mc > 0 ? mc : 0.55
        let si          = defaults.integer(forKey: Keys.scanInterval)
        scanInterval    = si > 0 ? si : 300
        let mt          = defaults.integer(forKey: Keys.maxTrades)
        maxTrades       = mt > 0 ? mt : 2
        let ad          = defaults.object(forKey: Keys.adaptive)
        adaptive        = ad == nil ? true : defaults.bool(forKey: Keys.adaptive)
        let dr          = defaults.object(forKey: Keys.dryRun)
        dryRun          = dr == nil ? true : defaults.bool(forKey: Keys.dryRun)
    }

    // MARK: - Polling

    func startPolling(client: APIClient) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(client: client)
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(client: APIClient) async {
        do {
            async let s = client.trendAgentStatus()
            async let sig = client.trendAgentSignals()
            async let learn = client.trendAgentLearning()
            status = try await s
            signals = try await sig
            learning = try await learn
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Launch / Stop

    func launch(client: APIClient) {
        save()
        if !dryRun {
            showLiveConfirmation = true
            Haptics.warning()
            return
        }
        Task { await doLaunch(client: client) }
    }

    func confirmLiveLaunch(client: APIClient) {
        showLiveConfirmation = false
        Task { await doLaunch(client: client) }
    }

    private func doLaunch(client: APIClient) async {
        isLaunching = true
        launchError = nil
        launchSuccess = nil
        defer { isLaunching = false }
        let params = TrendAgentParams(
            symbols: selectedSymbols,
            capital: capital,
            riskPct: riskPct,
            minConfidence: minConfidence,
            scanInterval: scanInterval,
            maxTrades: maxTrades,
            adaptive: adaptive,
            dryRun: dryRun
        )
        do {
            let resp = try await client.startTrendAgent(params)
            launchSuccess = "Started: \(resp.engine ?? "trend-agent")"
            Haptics.success()
            await refresh(client: client)
        } catch let err as APIError {
            launchError = err.errorDescription
            Haptics.error()
        } catch {
            launchError = error.localizedDescription
            Haptics.error()
        }
    }

    func stop(client: APIClient) {
        Task {
            isStopping = true
            defer { isStopping = false }
            do {
                _ = try await client.stopTrendAgent()
                Haptics.success()
                await refresh(client: client)
            } catch let err as APIError {
                launchError = err.errorDescription
                Haptics.error()
            } catch {
                launchError = error.localizedDescription
                Haptics.error()
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(selectedSymbols,  forKey: Keys.symbols)
        defaults.set(capital,          forKey: Keys.capital)
        defaults.set(riskPct,          forKey: Keys.riskPct)
        defaults.set(minConfidence,    forKey: Keys.minConfidence)
        defaults.set(scanInterval,     forKey: Keys.scanInterval)
        defaults.set(maxTrades,        forKey: Keys.maxTrades)
        defaults.set(adaptive,         forKey: Keys.adaptive)
        defaults.set(dryRun,           forKey: Keys.dryRun)
    }
}
