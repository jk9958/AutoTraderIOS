import SwiftUI
import Combine

private enum Keys {
    static let expiry          = "ic_expiry"
    static let instrument      = "ic_instrument"
    static let lots            = "ic_lots"
    static let spreadPts       = "ic_spread_pts"
    static let wingPts         = "ic_wing_pts"
    static let hardStopBuffer  = "ic_hard_stop_buffer"
    static let profitTarget    = "ic_profit_target"
    static let slMultiplier    = "ic_sl_multiplier"
    static let entryStart      = "ic_entry_start"
    static let entryCutoff     = "ic_entry_cutoff"
    static let eodExit         = "ic_eod_exit"
    static let holdOvernight   = "ic_hold_overnight"
    static let dryRun          = "ic_dry_run"

    // VIX Scalp
    static let vsLots          = "vs_lots"
    static let vsMinVix        = "vs_min_vix"
    static let vsVixSpikePct   = "vs_vix_spike_pct"
    static let vsVixLookback   = "vs_vix_lookback"
    static let vsProfitTarget  = "vs_profit_target"
    static let vsStopLoss      = "vs_stop_loss"
    static let vsDryRun        = "vs_dry_run"
}

@MainActor
final class TradeVM: ObservableObject {
    // Iron Condor form
    @Published var icExpiry: String
    @Published var icInstrument: String
    @Published var icLots: Int
    @Published var icSpreadPts: Int
    @Published var icWingPts: Int
    @Published var icHardStopBuffer: Int
    @Published var icProfitTarget: Double
    @Published var icSlMultiplier: Double
    @Published var icEntryStart: String
    @Published var icEntryCutoff: String
    @Published var icEodExit: String
    @Published var icHoldOvernight: Bool
    @Published var icDryRun: Bool

    // VIX Scalp form
    @Published var vsLots: Int
    @Published var vsMinVix: Double
    @Published var vsVixSpikePct: Double
    @Published var vsVixLookback: Int
    @Published var vsProfitTarget: Double
    @Published var vsStopLoss: Double
    @Published var vixScalpDryRun: Bool

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
        icExpiry          = defaults.string(forKey: Keys.expiry) ?? nextExpiry
        icInstrument      = defaults.string(forKey: Keys.instrument) ?? "nifty"
        icLots            = defaults.integer(forKey: Keys.lots) > 0 ? defaults.integer(forKey: Keys.lots) : 1
        icSpreadPts       = defaults.integer(forKey: Keys.spreadPts) > 0 ? defaults.integer(forKey: Keys.spreadPts) : 600
        icWingPts         = defaults.integer(forKey: Keys.wingPts) > 0 ? defaults.integer(forKey: Keys.wingPts) : 200
        icHardStopBuffer  = defaults.integer(forKey: Keys.hardStopBuffer) > 0 ? defaults.integer(forKey: Keys.hardStopBuffer) : 50
        let pt            = defaults.double(forKey: Keys.profitTarget)
        icProfitTarget    = pt > 0 ? pt : 0.50
        let sl            = defaults.double(forKey: Keys.slMultiplier)
        icSlMultiplier    = sl > 0 ? sl : 1.0
        icEntryStart      = defaults.string(forKey: Keys.entryStart) ?? "09:30"
        icEntryCutoff     = defaults.string(forKey: Keys.entryCutoff) ?? "11:00"
        icEodExit         = defaults.string(forKey: Keys.eodExit) ?? "15:15"
        let ho            = defaults.object(forKey: Keys.holdOvernight)
        icHoldOvernight   = ho != nil ? defaults.bool(forKey: Keys.holdOvernight) : false
        let dr            = defaults.object(forKey: Keys.dryRun)
        icDryRun          = dr == nil ? true : defaults.bool(forKey: Keys.dryRun)

        // VIX Scalp
        vsLots         = defaults.integer(forKey: Keys.vsLots) > 0 ? defaults.integer(forKey: Keys.vsLots) : 1
        let vMin       = defaults.double(forKey: Keys.vsMinVix)
        vsMinVix       = vMin > 0 ? vMin : 14.0
        let vSpike     = defaults.double(forKey: Keys.vsVixSpikePct)
        vsVixSpikePct  = vSpike > 0 ? vSpike : 0.015
        vsVixLookback  = defaults.integer(forKey: Keys.vsVixLookback) > 0 ? defaults.integer(forKey: Keys.vsVixLookback) : 6
        let vPt        = defaults.double(forKey: Keys.vsProfitTarget)
        vsProfitTarget = vPt > 0 ? vPt : 0.50
        let vSl        = defaults.double(forKey: Keys.vsStopLoss)
        vsStopLoss     = vSl > 0 ? vSl : 0.30
        let vDr        = defaults.object(forKey: Keys.vsDryRun)
        vixScalpDryRun = vDr == nil ? true : defaults.bool(forKey: Keys.vsDryRun)
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
            hardStopBuffer: icHardStopBuffer,
            profitTarget: icProfitTarget, slMultiplier: icSlMultiplier,
            entryStart: icEntryStart, entryCutoff: icEntryCutoff,
            eodExit: icEodExit, holdOvernight: icHoldOvernight, dryRun: icDryRun
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

    // MARK: - Launch VIX Scalp

    func launchVixScalp(appState: AppState) {
        saveVixScalpDefaults()
        if !vixScalpDryRun {
            pendingLaunchAction = { [weak self] in
                await self?.doLaunchVixScalp(appState: appState)
            }
            showLiveConfirmation = true
            Haptics.warning()
            return
        }
        Task { await doLaunchVixScalp(appState: appState) }
    }

    private func doLaunchVixScalp(appState: AppState) async {
        isLaunching = true
        launchError = nil
        launchSuccess = nil
        defer { isLaunching = false }
        let params = VixScalpParams(
            lots: vsLots,
            minVix: vsMinVix,
            vixSpikePct: vsVixSpikePct,
            vixLookback: vsVixLookback,
            profitTarget: vsProfitTarget,
            stopLoss: vsStopLoss,
            dryRun: vixScalpDryRun
        )
        do {
            let resp = try await appState.client.startVixScalp(params)
            launchSuccess = "Started: \(resp.engine ?? "vix-scalp")"
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

    // MARK: - Launch Options

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
        defaults.set(icExpiry,          forKey: Keys.expiry)
        defaults.set(icInstrument,      forKey: Keys.instrument)
        defaults.set(icLots,            forKey: Keys.lots)
        defaults.set(icSpreadPts,       forKey: Keys.spreadPts)
        defaults.set(icWingPts,         forKey: Keys.wingPts)
        defaults.set(icHardStopBuffer,  forKey: Keys.hardStopBuffer)
        defaults.set(icProfitTarget,    forKey: Keys.profitTarget)
        defaults.set(icSlMultiplier,    forKey: Keys.slMultiplier)
        defaults.set(icEntryStart,      forKey: Keys.entryStart)
        defaults.set(icEntryCutoff,     forKey: Keys.entryCutoff)
        defaults.set(icEodExit,         forKey: Keys.eodExit)
        defaults.set(icHoldOvernight,   forKey: Keys.holdOvernight)
        defaults.set(icDryRun,          forKey: Keys.dryRun)
    }

    private func saveVixScalpDefaults() {
        defaults.set(vsLots,         forKey: Keys.vsLots)
        defaults.set(vsMinVix,       forKey: Keys.vsMinVix)
        defaults.set(vsVixSpikePct,  forKey: Keys.vsVixSpikePct)
        defaults.set(vsVixLookback,  forKey: Keys.vsVixLookback)
        defaults.set(vsProfitTarget, forKey: Keys.vsProfitTarget)
        defaults.set(vsStopLoss,     forKey: Keys.vsStopLoss)
        defaults.set(vixScalpDryRun, forKey: Keys.vsDryRun)
    }
}
