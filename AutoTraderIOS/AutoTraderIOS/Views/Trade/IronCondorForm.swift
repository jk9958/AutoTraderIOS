import SwiftUI

struct IronCondorForm: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TradeVM
    @State private var showStopFirst = false

    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Expiry
            VStack(alignment: .leading, spacing: 4) {
                Text("Expiry").sectionLabel()
                TextField("e.g. 26521", text: $vm.icExpiry)
                    .inputStyle()
            }

            // Instrument
            VStack(alignment: .leading, spacing: 4) {
                Text("Instrument").sectionLabel()
                Picker("Instrument", selection: $vm.icInstrument) {
                    Text("NIFTY").tag("nifty")
                    Text("BANKNIFTY").tag("banknifty")
                }
                .pickerStyle(.segmented)
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
            HStack(spacing: 16) {
                timeField("Entry Start",  $vm.icEntryStart)
                timeField("Entry Cutoff", $vm.icEntryCutoff)
                timeField("EOD Exit",     $vm.icEodExit)
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
                Text(success).font(.caption).foregroundColor(Theme.green)
            }
            if let err = vm.launchError {
                Text(err).font(.caption).foregroundColor(Theme.red)
            }

            // Launch
            if engineRunning {
                Text("Stop the current engine first.")
                    .font(.caption)
                    .foregroundColor(Theme.orange)
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
        HStack {
            Text(label).foregroundColor(Theme.textSecondary).font(.subheadline)
            Spacer()
            Stepper("\(value.wrappedValue)", value: value, in: range, step: step)
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundColor(Theme.textSecondary).font(.subheadline)
                Spacer()
                Text(format(value.wrappedValue)).foregroundColor(Theme.textPrimary).font(.subheadline.monospacedDigit())
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.blue)
        }
    }

    private func timeField(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(Theme.textSecondary)
            TextField("HH:MM", text: binding)
                .inputStyle()
                .keyboardType(.numbersAndPunctuation)
        }
    }
}

private extension Text {
    func sectionLabel() -> some View {
        self.font(.caption).foregroundColor(Theme.textSecondary)
    }
}

private extension View {
    func inputStyle() -> some View {
        self
            .padding(8)
            .background(Theme.background)
            .cornerRadius(8)
            .foregroundColor(Theme.textPrimary)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
    }
}
