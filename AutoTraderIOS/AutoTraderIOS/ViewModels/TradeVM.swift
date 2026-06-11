import SwiftUI
import Combine

private enum Keys {
    static let expiry      = "ic_expiry"
    static let instrument  = "ic_instrument"
    static let lots        = "ic_lots"
    static let spreadPts   = "ic_spread_pts"
    static let wingPts     = "ic_wing_pts"
    static let profitTarget = "ic_profit_target"
    static let slMultiplier = "ic_sl_multiplier"
    static let entryStart  = "ic_entry_start"
    static let entryCutoff = "ic_entry_cutoff"
    static let eodExit     = "ic_eod_exit"
    static let dryRun      = "ic_dry_run"
}

@MainActor
final class TradeVM: ObservableObject {
    // Iron Condor form
    @Published var icExpiry: String
    @Published var icInstrument: String
    @Published var icLots: Int
    @Published var icSpreadPts: Int
    @Published var icWingPts: Int
    @Published var icProfitTarget: Double
    @Published var icSlMultiplier: Double
    @Published var icEntryStart: String
    @Published var icEntryCutoff: String
    @Published var icEodExit: String
    @Published var icDryRun: Bool

    // Scalping
    @Published var scalpingDryRun = true

    // Options
    @Published var optionsDryRun = true

    // Actions
    @Published var isLaunching = false
    @Published var launchError: String?
    @Published var launchSuccess: String?
    @Published var showLiveConfirmation = false
    @Published var pendingLaunchAction: (() async -> Void)?

    // Margin estimate
    @Published var marginEstimate: MarginResponse?
    @Published var isEstimatingMargin = false
    @Published var marginError: String?

    private let defaults = UserDefaults.standard

    init(nextExpiry: String = "") {
        icExpiry      = defaults.string(forKey: Keys.expiry) ?? nextExpiry
        icInstrument  = defaults.string(forKey: Keys.instrument) ?? "nifty"
        icLots        = defaults.integer(forKey: Keys.lots) > 0 ? defaults.integer(forKey: Keys.lots) : 1
        icSpreadPts   = defaults.integer(forKey: Keys.spreadPts) > 0 ? defaults.integer(forKey: Keys.spreadPts) : 400
        icWingPts     = defaults.integer(forKey: Keys.wingPts) > 0 ? defaults.integer(forKey: Keys.wingPts) : 200
        let pt = defaults.double(forKey: Keys.profitTarget)
        icProfitTarget = pt > 0 ? pt : 0.50
        let sl = defaults.double(forKey: Keys.slMultiplier)
        icSlMultiplier = sl > 0 ? sl : 1.0
        icEntryStart  = defaults.string(forKey: Keys.entryStart) ?? "09:30"
        icEntryCutoff = defaults.string(forKey: Keys.entryCutoff) ?? "11:00"
        icEodExit     = defaults.string(forKey: Keys.eodExit) ?? "15:15"
        let dr = defaults.object(forKey: Keys.dryRun)
        icDryRun      = dr == nil ? true : defaults.bool(forKey: Keys.dryRun)
    }

    func prefill(nextExpiry: String) {
        if icExpiry.isEmpty { icExpiry = nextExpiry }
    }

    // MARK: - Launch Iron Condor

    func launchIronCondor(appState: AppState) {
        saveIronCondorDefaults()
        if !icDryRun {
            pendingLaunchAction = { [weak self] in
                await self?.doLaunchIronCondor(appState: appState)
            }
            showLiveConfirmation = true
            Haptics.warning()
            return
        }
        Task { await doLaunchIronCondor(appState: appState) }
    }

    private func doLaunchIronCondor(appState: AppState) async {
        isLaunching = true
        launchError = nil
        launchSuccess = nil
        defer { isLaunching = false }
        let params = IronCondorParams(
            expiry: icExpiry, instrument: icInstrument, lots: icLots,
            spreadPts: icSpreadPts, wingPts: icWingPts,
            profitTarget: icProfitTarget, slMultiplier: icSlMultiplier,
            entryStart: icEntryStart, entryCutoff: icEntryCutoff,
            eodExit: icEodExit, dryRun: icDryRun
        )
        do {
            let resp = try await appState.client.startIronCondor(params)
            launchSuccess = "Started: \(resp.engine ?? "iron-condor")"
            Haptics.success()
            await appState.fetchStatus()
        } catch let err as APIError {
            launchError = err.errorDescription
            Haptics.error()
        } catch {
            launchError = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Launch Simple Engines

    func launchScalping(appState: AppState) {
        if !scalpingDryRun {
            pendingLaunchAction = { [weak self] in
                await self?.doLaunchSimple("scalping", dryRun: self?.scalpingDryRun ?? true, appState: appState)
            }
            showLiveConfirmation = true
            Haptics.warning()
            return
        }
        Task { await doLaunchSimple("scalping", dryRun: scalpingDryRun, appState: appState) }
    }

    func launchOptions(appState: AppState) {
        if !optionsDryRun {
            pendingLaunchAction = { [weak self] in
                await self?.doLaunchSimple("options", dryRun: self?.optionsDryRun ?? true, appState: appState)
            }
            showLiveConfirmation = true
            Haptics.warning()
            return
        }
        Task { await doLaunchSimple("options", dryRun: optionsDryRun, appState: appState) }
    }

    private func doLaunchSimple(_ name: String, dryRun: Bool, appState: AppState) async {
        isLaunching = true
        launchError = nil
        launchSuccess = nil
        defer { isLaunching = false }
        do {
            let resp = try await appState.client.startEngine(name: name, dryRun: dryRun)
            launchSuccess = "Started: \(resp.engine ?? name)"
            Haptics.success()
            await appState.fetchStatus()
        } catch let err as APIError {
            launchError = err.errorDescription
            Haptics.error()
        } catch {
            launchError = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Confirmation

    func confirmLiveAction() async {
        showLiveConfirmation = false
        if let action = pendingLaunchAction {
            pendingLaunchAction = nil
            await action()
        }
    }

    func cancelLiveAction() {
        showLiveConfirmation = false
        pendingLaunchAction = nil
    }

    // MARK: - Margin Estimate

    func estimateMargin(appState: AppState) {
        Task {
            isEstimatingMargin = true
            marginError = nil
            defer { isEstimatingMargin = false }
            do {
                marginEstimate = try await appState.client.ironCondorMargin(
                    instrument: icInstrument,
                    lots: icLots,
                    spreadPts: icSpreadPts,
                    wingPts: icWingPts,
                    expiry: icExpiry
                )
                Haptics.success()
            } catch let err as APIError {
                marginError = err.errorDescription
                Haptics.error()
            } catch {
                marginError = error.localizedDescription
                Haptics.error()
            }
        }
    }

    // MARK: - Persistence

    private func saveIronCondorDefaults() {
        defaults.set(icExpiry,       forKey: Keys.expiry)
        defaults.set(icInstrument,   forKey: Keys.instrument)
        defaults.set(icLots,         forKey: Keys.lots)
        defaults.set(icSpreadPts,    forKey: Keys.spreadPts)
        defaults.set(icWingPts,      forKey: Keys.wingPts)
        defaults.set(icProfitTarget, forKey: Keys.profitTarget)
        defaults.set(icSlMultiplier, forKey: Keys.slMultiplier)
        defaults.set(icEntryStart,   forKey: Keys.entryStart)
        defaults.set(icEntryCutoff,  forKey: Keys.entryCutoff)
        defaults.set(icEodExit,      forKey: Keys.eodExit)
        defaults.set(icDryRun,       forKey: Keys.dryRun)
    }
}
