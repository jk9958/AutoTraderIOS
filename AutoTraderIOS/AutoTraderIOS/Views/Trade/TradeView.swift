import SwiftUI

struct TradeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradeVM()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink {
                        IronCondorDetailView(vm: vm)
                            .environmentObject(appState)
                    } label: {
                        StrategyCard(
                            title: "Iron Condor",
                            subtitle: "Delta-neutral options spread",
                            icon: "arrow.left.and.right",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        VixScalpDetailView(vm: vm)
                            .environmentObject(appState)
                    } label: {
                        StrategyCard(
                            title: "VIX Scalp",
                            subtitle: "Intraday ATM PUT on VIX spike",
                            icon: "bolt.fill",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SimpleStrategyView(
                            title: "Options",
                            dryRun: $vm.optionsDryRun,
                            vm: vm,
                            onLaunch: { vm.launchOptions(appState: appState) }
                        )
                        .environmentObject(appState)
                    } label: {
                        StrategyCard(
                            title: "Options",
                            subtitle: "Directional options trading",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Trade")
            .onAppear {
                if let status = appState.serverStatus, let expiry = status.nextExpiry {
                    vm.prefill(nextExpiry: expiry)
                }
            }
            .onChange(of: appState.serverStatus?.nextExpiry) { _, expiry in
                if let expiry { vm.prefill(nextExpiry: expiry) }
            }
        }
    }
}

// MARK: - Strategy Card

private struct StrategyCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .thinGlassCard()
    }
}

// MARK: - VIX Scalp Detail

private struct VixScalpDetailView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TradeVM
    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        Form {
            Section("Position") {
                Stepper("Lots: \(vm.vsLots)", value: $vm.vsLots, in: 1...50)
            }

            Section {
                LabeledContent("Min VIX") {
                    Text(String(format: "%.1f", vm.vsMinVix)).monospacedDigit()
                }
                Slider(value: $vm.vsMinVix, in: 10...30, step: 0.5).tint(.orange)
                    .listRowSeparator(.hidden)

                LabeledContent("VIX Spike") {
                    Text(String(format: "%.1f%%", vm.vsVixSpikePct * 100)).monospacedDigit()
                }
                Slider(value: $vm.vsVixSpikePct, in: 0.005...0.05, step: 0.005).tint(.orange)
                    .listRowSeparator(.hidden)

                Stepper("Lookback: \(vm.vsVixLookback) candles (\(vm.vsVixLookback * 5)m)",
                        value: $vm.vsVixLookback, in: 1...24)
            } header: {
                Text("VIX Trigger")
            } footer: {
                Text("Enter ATM PUT when VIX ≥ Min VIX and rises by the spike % over the lookback window (×5 min candles).")
            }

            Section {
                LabeledContent("Profit Target") {
                    Text(String(format: "%.0f%%", vm.vsProfitTarget * 100)).monospacedDigit()
                }
                Slider(value: $vm.vsProfitTarget, in: 0.1...1.0, step: 0.05).tint(.green)
                    .listRowSeparator(.hidden)

                LabeledContent("Stop Loss") {
                    Text(String(format: "%.0f%%", vm.vsStopLoss * 100)).monospacedDigit()
                }
                Slider(value: $vm.vsStopLoss, in: 0.1...0.9, step: 0.05).tint(.red)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Exit")
            }

            Section {
                Toggle(isOn: $vm.vixScalpDryRun) {
                    Label("Dry Run", systemImage: "play.circle")
                }
                if !vm.vixScalpDryRun {
                    Label("Live orders will be placed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            } header: {
                Text("Mode")
            }

            Section {
                if engineRunning {
                    Label("Stop the running engine first", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                Button {
                    vm.launchVixScalp(appState: appState)
                } label: {
                    HStack {
                        Spacer()
                        if vm.isLaunching {
                            ProgressView().progressViewStyle(.circular)
                                .tint(vm.vixScalpDryRun ? .blue : .red)
                                .padding(.trailing, 6)
                        }
                        Text(vm.isLaunching ? "Launching…" : "Launch VIX Scalp")
                            .foregroundStyle(vm.vixScalpDryRun ? .blue : .red)
                        Spacer()
                    }
                }
                .disabled(engineRunning || vm.isLaunching)

                if let success = vm.launchSuccess {
                    Label(success, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                if let err = vm.launchError {
                    Label(err, systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.caption)
                }
            } header: {
                Text("Launch")
            }
        }
        .navigationTitle("VIX Scalp")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "LIVE Mode — real orders will be placed",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Place LIVE Orders", role: .destructive) {
                Task { await vm.confirmLiveAction() }
            }
            Button("Cancel", role: .cancel) { vm.cancelLiveAction() }
        }
    }
}

// MARK: - Simple Strategy Detail (Options)

private struct SimpleStrategyView: View {
    @EnvironmentObject var appState: AppState
    let title: String
    @Binding var dryRun: Bool
    @ObservedObject var vm: TradeVM
    let onLaunch: () -> Void

    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $dryRun) {
                    Label("Dry Run", systemImage: "play.circle")
                }
                if !dryRun {
                    Label("Live orders will be placed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            } header: {
                Text("Mode")
            }

            Section {
                if engineRunning {
                    Label("Stop the running engine first", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                Button {
                    onLaunch()
                } label: {
                    HStack {
                        Spacer()
                        if vm.isLaunching {
                            ProgressView().progressViewStyle(.circular)
                                .tint(dryRun ? .blue : .red)
                                .padding(.trailing, 6)
                        }
                        Text(vm.isLaunching ? "Launching…" : "Launch \(title)")
                            .foregroundStyle(dryRun ? .blue : .red)
                        Spacer()
                    }
                }
                .disabled(engineRunning || vm.isLaunching)

                if let success = vm.launchSuccess {
                    Label(success, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                if let err = vm.launchError {
                    Label(err, systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.caption)
                }
            } header: {
                Text("Launch")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "LIVE Mode — real orders will be placed",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Place LIVE Orders", role: .destructive) {
                Task { await vm.confirmLiveAction() }
            }
            Button("Cancel", role: .cancel) { vm.cancelLiveAction() }
        }
    }
}
