import SwiftUI
import Combine

@MainActor
final class LaunchVM: ObservableObject {
    enum Strategy: String, CaseIterable, Identifiable {
        case ironCondor = "iron-condor"
        case vixScalp = "vix-scalp"
        case trend = "trend"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .ironCondor: return "Iron Condor"
            case .vixScalp: return "VIX Scalp"
            case .trend: return "Trend"
            }
        }
        var isIronCondor: Bool { self == .ironCondor }
    }

    enum Broker: String, CaseIterable, Identifiable {
        case fyers, kite, tradesmart
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum Instrument: String, CaseIterable, Identifiable {
        case nifty, sensex
        var id: String { rawValue }
        var label: String { rawValue.uppercased() }
    }

    @Published var strategy: Strategy = .ironCondor
    @Published var broker: Broker = .fyers
    @Published var instrument: Instrument = .nifty
    @Published var expiry: ExpiryHelper.Expiry?
    @Published var lots = 1
    @Published var dryRun = true

    // Advanced (Iron Condor)
    @Published var spreadPts = 400
    @Published var wingPts = 200
    @Published var profitTarget = 0.50
    @Published var slMultiplier = 1.0
    @Published var entryStart = "09:30"
    @Published var entryCutoff = "11:00"
    @Published var eodExit = "15:15"

    // Launch state
    @Published var isLaunching = false
    @Published var launchError: String?
    @Published var showLiveConfirm = false

    // Margin estimate
    @Published var marginEstimate: MarginResponse?
    @Published var isEstimating = false
    @Published var marginError: String?

    var expiries: [ExpiryHelper.Expiry] {
        ExpiryHelper.weeklyExpiries(instrument: instrument.rawValue)
    }

    func refreshExpiry() {
        let list = expiries
        if expiry == nil || !list.contains(where: { $0.id == expiry?.id }) {
            expiry = list.first
        }
    }

    private func buildRequest() -> LaunchRequest {
        if strategy.isIronCondor {
            return LaunchRequest(
                strategy: strategy.rawValue, broker: broker.rawValue, dryRun: dryRun,
                instrument: instrument.rawValue, expiry: expiry?.fyers, lots: lots
            )
        }
        return LaunchRequest(strategy: strategy.rawValue, broker: broker.rawValue, dryRun: dryRun)
    }

    /// Returns true on success so the sheet can dismiss.
    func launch(appState: AppState) async -> Bool {
        isLaunching = true
        launchError = nil
        defer { isLaunching = false }
        do {
            _ = try await appState.client.launchEngine(buildRequest())
            Haptics.success()
            return true
        } catch let err as APIError {
            launchError = err.errorDescription
            Haptics.error()
            return false
        } catch {
            launchError = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    func estimateMargin(appState: AppState) async {
        guard let expiry else { return }
        isEstimating = true
        marginError = nil
        defer { isEstimating = false }
        do {
            marginEstimate = try await appState.client.ironCondorMargin(
                instrument: instrument.rawValue, lots: lots,
                spreadPts: spreadPts, wingPts: wingPts, expiry: expiry.fyers
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

struct LaunchSheet: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LaunchVM()
    @Environment(\.dismiss) private var dismiss
    var onLaunched: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Strategy") {
                    Picker("Strategy", selection: $vm.strategy) {
                        ForEach(LaunchVM.Strategy.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Broker", selection: $vm.broker) {
                        ForEach(LaunchVM.Broker.allCases) { Text($0.label).tag($0) }
                    }
                }

                if vm.strategy.isIronCondor {
                    Section("Contract") {
                        Picker("Instrument", selection: $vm.instrument) {
                            ForEach(LaunchVM.Instrument.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Expiry", selection: $vm.expiry) {
                            ForEach(vm.expiries) { Text($0.label).tag(Optional($0)) }
                        }
                        Stepper("Lots: \(vm.lots)", value: $vm.lots, in: 1...50)
                    }

                    DisclosureGroup("Advanced") {
                        Stepper("Spread: \(vm.spreadPts) pts", value: $vm.spreadPts, in: 50...2000, step: 50)
                        Stepper("Wings: \(vm.wingPts) pts", value: $vm.wingPts, in: 50...2000, step: 50)
                        LabeledContent("Profit target") {
                            Text(String(format: "%.0f%%", vm.profitTarget * 100))
                        }
                        Slider(value: $vm.profitTarget, in: 0.1...1.0, step: 0.05)
                        LabeledContent("SL multiplier") {
                            Text(String(format: "%.1f×", vm.slMultiplier))
                        }
                        Slider(value: $vm.slMultiplier, in: 0.5...3.0, step: 0.1)
                        TextField("Entry start (HH:MM)", text: $vm.entryStart)
                        TextField("Entry cutoff (HH:MM)", text: $vm.entryCutoff)
                        TextField("EOD exit (HH:MM)", text: $vm.eodExit)
                    }

                    Section {
                        Button {
                            Task { await vm.estimateMargin(appState: appState) }
                        } label: {
                            HStack {
                                Label("Estimate margin", systemImage: "indianrupeesign.circle")
                                Spacer()
                                if vm.isEstimating { ProgressView() }
                            }
                        }
                        if let m = vm.marginEstimate {
                            LabeledContent("Margin required", value: "₹\(m.marginRequired)")
                            LabeledContent("Per lot", value: "₹\(m.perLot)")
                        }
                        if let e = vm.marginError {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Toggle("Practice mode (dry run)", isOn: $vm.dryRun)
                } footer: {
                    Text(vm.dryRun
                         ? "No real orders are placed."
                         : "⚠️ LIVE mode places real orders with real money.")
                }

                Section {
                    Button {
                        if vm.dryRun {
                            Task { await submit() }
                        } else {
                            vm.showLiveConfirm = true
                            Haptics.warning()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isLaunching {
                                ProgressView()
                            } else {
                                Text(vm.dryRun ? "Launch (Practice)" : "Launch LIVE")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isLaunching || !appState.hasAPIKey)
                    if !appState.hasAPIKey {
                        Text("Set an API key in Settings to launch engines.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let err = vm.launchError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Launch Engine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { vm.refreshExpiry() }
            .onChange(of: vm.instrument) { _, _ in vm.refreshExpiry() }
            .confirmationDialog("Launch LIVE engine?", isPresented: $vm.showLiveConfirm, titleVisibility: .visible) {
                Button("Launch LIVE", role: .destructive) { Task { await submit() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This places real orders with real money.")
            }
        }
    }

    private func submit() async {
        let ok = await vm.launch(appState: appState)
        if ok {
            onLaunched()
            dismiss()
        }
    }
}
