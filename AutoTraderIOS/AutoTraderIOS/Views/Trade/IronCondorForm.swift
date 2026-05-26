import SwiftUI

struct IronCondorForm: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TradeVM
    @State private var showStopFirst = false

    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Expiry
            VStack(alignment: .leading, spacing: 6) {
                Text("EXPIRY DATE")
                    .sectionLabel()
                    .tracking(0.5)
                TextField("e.g. 26521", text: $vm.icExpiry)
                    .inputStyle()
                Text("Weekly or monthly in YYMMDD format")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            }

            // Instrument
            VStack(alignment: .leading, spacing: 6) {
                Text("INSTRUMENT")
                    .sectionLabel()
                    .tracking(0.5)
                Picker("Instrument", selection: $vm.icInstrument) {
                    Text("NIFTY").tag("nifty")
                    Text("BANKNIFTY").tag("banknifty")
                }
                .pickerStyle(.segmented)
                .tint(Theme.blue)
            }

            // Lots
            stepperRow("Lots", value: $vm.icLots, range: 1...50)

            // Spread / Wing
            stepperRow("Spread Points", value: $vm.icSpreadPts, range: 50...2000, step: 50)
            stepperRow("Wing Points",   value: $vm.icWingPts,   range: 50...2000, step: 50)

            // Profit Target
            sliderRow("Profit Target", value: $vm.icProfitTarget,
                      range: 0.1...1.0, step: 0.05,
                      format: { String(format: "%.2f", $0) })

            // SL Multiplier
            sliderRow("SL Multiplier", value: $vm.icSlMultiplier,
                      range: 0.5...5.0, step: 0.1,
                      format: { String(format: "%.1f", $0) })

            // Times
            VStack(alignment: .leading, spacing: 4) {
                Text("TIMING")
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                    .tracking(0.5)
                HStack(spacing: 12) {
                    timeField("Start",  $vm.icEntryStart)
                    timeField("Cutoff", $vm.icEntryCutoff)
                    timeField("EOD",    $vm.icEodExit)
                }
            }

            // Dry Run
            Toggle(isOn: $vm.icDryRun) {
                HStack {
                    Text("Dry Run")
                        .foregroundColor(Theme.textPrimary)
                    if !vm.icDryRun {
                        StatusPill(label: "LIVE", color: Theme.red)
                    }
                }
            }
            .tint(Theme.green)

            // Feedback
            if let success = vm.launchSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.green)
                    Text(success)
                        .font(.caption)
                        .foregroundColor(Theme.green)
                }
                .padding(10)
                .background(Theme.green.opacity(0.12))
                .cornerRadius(8)
            }
            if let err = vm.launchError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(Theme.red)
                    Spacer()
                }
                .padding(10)
                .background(Theme.red.opacity(0.12))
                .cornerRadius(8)
            }

            // Launch
            if engineRunning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.orange)
                    Text("Stop the running engine first")
                        .font(.caption)
                        .foregroundColor(Theme.orange)
                    Spacer()
                }
                .padding(10)
                .background(Theme.orange.opacity(0.12))
                .cornerRadius(8)
            }

            LoadingButton("Launch Iron Condor", isLoading: vm.isLaunching, color: Theme.blue) {
                if engineRunning { showStopFirst = true }
                else { vm.launchIronCondor(appState: appState) }
            }
            .disabled(engineRunning || vm.isLaunching)
        }
        .alert("Stop running engine first.", isPresented: $showStopFirst) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog(
            "⚠️ LIVE Mode — real orders will be placed. Are you sure?",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Place LIVE Orders", role: .destructive) {
                Task { await vm.confirmLiveAction() }
            }
            Button("Cancel", role: .cancel) {
                vm.cancelLiveAction()
            }
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(Theme.blue)
            }
            Stepper("", value: value, in: range, step: step)
                .tint(Theme.blue)
        }
        .padding(10)
        .background(Theme.glassAccent)
        .cornerRadius(8)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.headline.monospacedDigit())
                    .foregroundColor(Theme.green)
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.blue)
        }
        .padding(10)
        .background(Theme.glassAccent)
        .cornerRadius(8)
    }

    private func timeField(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(Theme.textSecondary)
                .tracking(0.3)
            TextField("HH:MM", text: binding)
                .inputStyle()
                .keyboardType(.numbersAndPunctuation)
        }
    }
}

private extension Text {
    func sectionLabel() -> some View {
        self
            .font(.caption.bold())
            .foregroundColor(Theme.textSecondary)
    }
}

private extension View {
    func inputStyle() -> some View {
        self
            .padding(10)
            .foregroundColor(Theme.textPrimary)
            .background(
                ZStack {
                    Theme.glassAccent
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            )
            .cornerRadius(8)
    }
}
