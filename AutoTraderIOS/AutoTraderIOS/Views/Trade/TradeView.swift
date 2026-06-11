import SwiftUI

struct TradeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradeVM()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        IronCondorDetailView(vm: vm)
                            .environmentObject(appState)
                    } label: {
                        strategyRow(
                            title: "Iron Condor",
                            subtitle: "Delta-neutral options spread",
                            icon: "arrow.left.and.right",
                            color: .blue
                        )
                    }

                    NavigationLink {
                        SimpleStrategyView(
                            title: "Scalping",
                            dryRun: $vm.scalpingDryRun,
                            vm: vm,
                            onLaunch: { vm.launchScalping(appState: appState) }
                        )
                        .environmentObject(appState)
                    } label: {
                        strategyRow(
                            title: "Scalping",
                            subtitle: "Short-term momentum strategy",
                            icon: "bolt.fill",
                            color: .orange
                        )
                    }

                    NavigationLink {
                        SimpleStrategyView(
                            title: "Options",
                            dryRun: $vm.optionsDryRun,
                            vm: vm,
                            onLaunch: { vm.launchOptions(appState: appState) }
                        )
                        .environmentObject(appState)
                    } label: {
                        strategyRow(
                            title: "Options",
                            subtitle: "Directional options trading",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                } header: {
                    Text("Strategies")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Trade")
            .onAppear {
                if let status = appState.serverStatus {
                    vm.prefill(nextExpiry: status.nextExpiry)
                }
            }
            .onChange(of: appState.serverStatus?.nextExpiry) { _, expiry in
                if let expiry { vm.prefill(nextExpiry: expiry) }
            }
        }
    }

    private func strategyRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Simple Strategy Detail

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
                            ProgressView()
                                .progressViewStyle(.circular)
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
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                if let err = vm.launchError {
                    Label(err, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .font(.caption)
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
