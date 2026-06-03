import SwiftUI

struct TrendLaunchForm: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TrendAgentVM

    private var scanIntervalLabel: String {
        let m = vm.scanInterval / 60
        let s = vm.scanInterval % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    var body: some View {
        Form {
            Section {
                Toggle("NIFTY", isOn: $vm.symbolNifty)
                Toggle("BANKNIFTY", isOn: $vm.symbolBankNifty)
            } header: {
                Text("Symbols")
            } footer: {
                Text("At least one symbol is required; NIFTY is used if none selected.")
            }

            Section("Capital & Risk") {
                LabeledContent("Capital") {
                    Text("₹\(Int(vm.capital).formatted())").monospacedDigit()
                }
                Slider(value: $vm.capital, in: 50_000...1_000_000, step: 50_000).tint(.blue)
                    .listRowSeparator(.hidden)

                LabeledContent("Risk per Trade") {
                    Text(String(format: "%.1f%%", vm.riskPct)).monospacedDigit()
                }
                Slider(value: $vm.riskPct, in: 0.5...5.0, step: 0.5).tint(.orange)
                    .listRowSeparator(.hidden)

                Stepper("Max Concurrent Trades: \(vm.maxTrades)", value: $vm.maxTrades, in: 1...5)
            }

            Section {
                LabeledContent("Min Confidence") {
                    Text(String(format: "%.0f%%", vm.minConfidence * 100)).monospacedDigit()
                }
                Slider(value: $vm.minConfidence, in: 0.3...0.9, step: 0.05).tint(.teal)
                    .listRowSeparator(.hidden)

                Picker("Scan Interval", selection: $vm.scanInterval) {
                    Text("1m").tag(60)
                    Text("3m").tag(180)
                    Text("5m").tag(300)
                    Text("10m").tag(600)
                    Text("15m").tag(900)
                }
            } header: {
                Text("Signal")
            } footer: {
                Text("Agent re-scans all timeframes every \(scanIntervalLabel) and only enters trades scoring above the confidence threshold.")
            }

            Section {
                Toggle(isOn: $vm.adaptive) {
                    Label("Adaptive Learning", systemImage: "brain.head.profile")
                }
            } header: {
                Text("Mode")
            } footer: {
                Text(vm.adaptive
                     ? "Self-learning: every 20 closed trades the agent evolves its own confidence, SL, target and filter parameters toward better ROI."
                     : "Static: fixed parameters, no self-tuning.")
            }

            Section {
                Toggle(isOn: $vm.dryRun) {
                    Label("Dry Run", systemImage: "play.circle")
                }
                if !vm.dryRun {
                    Label("Live orders will be placed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            } header: {
                Text("Execution")
            }

            Section {
                if vm.isRunning {
                    Label("Agent already running — stop it first", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                Button {
                    vm.launch(client: appState.client)
                } label: {
                    HStack {
                        Spacer()
                        if vm.isLaunching {
                            ProgressView().progressViewStyle(.circular)
                                .tint(vm.dryRun ? .blue : .red).padding(.trailing, 6)
                        }
                        Text(vm.isLaunching ? "Launching…" : "Launch Trend Agent")
                            .foregroundStyle(vm.dryRun ? .blue : .red)
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(vm.isRunning || vm.isLaunching)

                if let success = vm.launchSuccess {
                    Label(success, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                if let err = vm.launchError {
                    Label(err, systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "LIVE Mode — real option orders will be placed",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Launch LIVE Agent", role: .destructive) {
                vm.confirmLiveLaunch(client: appState.client)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
