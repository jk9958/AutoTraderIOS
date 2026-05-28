import SwiftUI

struct IronCondorDetailView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TradeVM

    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        Form {
            Section("Contract") {
                TextField("Expiry (YYMMDD)", text: $vm.icExpiry)
                    .keyboardType(.numberPad)
                Picker("Instrument", selection: $vm.icInstrument) {
                    Text("NIFTY").tag("nifty")
                    Text("BANKNIFTY").tag("banknifty")
                }
                .pickerStyle(.segmented)
                Stepper("Lots: \(vm.icLots)", value: $vm.icLots, in: 1...50)
            }

            Section("Structure") {
                Stepper("Spread: \(vm.icSpreadPts) pts", value: $vm.icSpreadPts, in: 50...2000, step: 50)
                Stepper("Wings: \(vm.icWingPts) pts", value: $vm.icWingPts, in: 50...2000, step: 50)
            }

            Section {
                LabeledContent("Profit Target") {
                    Text(String(format: "%.2f", vm.icProfitTarget))
                        .monospacedDigit()
                }
                Slider(value: $vm.icProfitTarget, in: 0.1...1.0, step: 0.05)
                    .tint(.blue)
                    .listRowSeparator(.hidden)
                LabeledContent("SL Multiplier") {
                    Text(String(format: "%.1fx", vm.icSlMultiplier))
                        .monospacedDigit()
                }
                Slider(value: $vm.icSlMultiplier, in: 0.5...5.0, step: 0.1)
                    .tint(.orange)
                    .listRowSeparator(.hidden)
            } header: {
                Text("Risk Management")
            }

            Section("Schedule") {
                LabeledContent("Start") {
                    TextField("HH:MM", text: $vm.icEntryStart)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Cutoff") {
                    TextField("HH:MM", text: $vm.icEntryCutoff)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("EOD Exit") {
                    TextField("HH:MM", text: $vm.icEodExit)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button {
                    vm.estimateMargin(appState: appState)
                } label: {
                    HStack {
                        Label("Estimate Margin", systemImage: "indianrupeesign.circle")
                        Spacer()
                        if vm.isEstimatingMargin {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                        }
                    }
                }
                .disabled(vm.isEstimatingMargin)

                if let m = vm.marginEstimate {
                    LabeledContent("Required") {
                        Text("₹\(m.marginRequired.formatted())")
                            .font(.headline.monospacedDigit())
                    }
                    LabeledContent("Per Lot") {
                        Text("₹\(m.perLot.formatted())")
                            .monospacedDigit()
                    }
                    LabeledContent("Spot / ATM") {
                        Text("\(m.spot.formatted(.number.precision(.fractionLength(0)))) / \(m.atm)")
                            .monospacedDigit()
                    }
                    LabeledContent("Method") {
                        Text(m.method == "fyers_span" ? "Fyers SPAN" : "Formula")
                            .foregroundStyle(m.method == "fyers_span" ? .green : .orange)
                    }
                    LabeledContent("Strikes") {
                        Text("S:\(m.legs.shortPe)/\(m.legs.shortCe)  L:\(m.legs.longPe)/\(m.legs.longCe)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if let err = vm.marginError {
                    Label(err, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } header: {
                Text("Margin")
            }

            Section {
                Toggle(isOn: $vm.icDryRun) {
                    Label("Dry Run", systemImage: "play.circle")
                }
                if !vm.icDryRun {
                    Label("Live orders will be placed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
                if engineRunning {
                    Label("Stop the running engine first", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                Button {
                    vm.launchIronCondor(appState: appState)
                } label: {
                    HStack {
                        Spacer()
                        if vm.isLaunching {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(vm.icDryRun ? .blue : .red)
                                .padding(.trailing, 6)
                        }
                        Text(vm.isLaunching ? "Launching…" : "Launch Iron Condor")
                            .foregroundStyle(vm.icDryRun ? .blue : .red)
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
                Text("Execution")
            }
        }
        .navigationTitle("Iron Condor")
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
