import SwiftUI

struct IronCondorForm: View {
    @Binding var params: IronCondorParams
    let validationErrors: [String: String]
    let isRunning: Bool
    let isLaunching: Bool
    let onLaunch: () -> Void

    private let instruments = ["nifty", "banknifty"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Expiry
            FormField(
                label: "Expiry",
                error: validationErrors["expiry"]
            ) {
                TextField("e.g. 26521", text: $params.expiry)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.text)
            }

            // Instrument
            FormField(label: "Instrument", error: validationErrors["instrument"]) {
                Picker("Instrument", selection: $params.instrument) {
                    ForEach(instruments, id: \.self) { inst in
                        Text(inst.uppercased()).tag(inst)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Lots
            FormField(label: "Lots (1–50)", error: validationErrors["lots"]) {
                Stepper("\(params.lots)", value: $params.lots, in: 1...50)
                    .foregroundColor(Theme.text)
            }

            // Spread & Wing
            HStack(spacing: 12) {
                FormField(label: "Spread pts (min 50)", error: validationErrors["spread_pts"]) {
                    TextField("400", value: $params.spreadPts, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text)
                }
                FormField(label: "Wing pts (min 50)", error: validationErrors["wing_pts"]) {
                    TextField("200", value: $params.wingPts, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text)
                }
            }

            // Profit target
            FormField(
                label: "Profit target: \(String(format: "%.2f", params.profitTarget))",
                error: validationErrors["profit_target"]
            ) {
                Slider(value: $params.profitTarget, in: 0.1...1.0, step: 0.05)
                    .tint(Theme.green)
            }

            // SL Multiplier
            FormField(
                label: "SL multiplier: \(String(format: "%.1f", params.slMultiplier))",
                error: validationErrors["sl_multiplier"]
            ) {
                Slider(value: $params.slMultiplier, in: 0.5...5.0, step: 0.5)
                    .tint(Theme.orange)
            }

            // Time fields
            HStack(spacing: 12) {
                FormField(label: "Entry start", error: validationErrors["entry_start"]) {
                    TextField("09:30", text: $params.entryStart)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text)
                        .font(.system(.body, design: .monospaced))
                }
                FormField(label: "Entry cutoff", error: validationErrors["entry_cutoff"]) {
                    TextField("11:00", text: $params.entryCutoff)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text)
                        .font(.system(.body, design: .monospaced))
                }
                FormField(label: "EOD exit", error: validationErrors["eod_exit"]) {
                    TextField("15:15", text: $params.eodExit)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text)
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Dry run toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dry run")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.text)
                    Text(params.dryRun ? "Simulation mode — no real orders" : "LIVE — real orders will be placed!")
                        .font(.caption)
                        .foregroundColor(params.dryRun ? Theme.textSecondary : Theme.red)
                }
                Spacer()
                Toggle("", isOn: $params.dryRun)
                    .tint(Theme.green)
                    .labelsHidden()
            }
            .padding(.top, 4)

            // Launch button
            if isRunning {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.orange)
                    Text("Stop the current engine first.")
                        .font(.subheadline)
                        .foregroundColor(Theme.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.orange.opacity(0.15))
                .cornerRadius(Theme.cornerRadius)
            } else {
                LoadingButton(
                    title: "Launch Iron Condor",
                    icon: "play.fill",
                    color: params.dryRun ? Theme.green : Theme.red,
                    isLoading: isLaunching,
                    isDisabled: params.expiry.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    onLaunch()
                }
            }
        }
    }
}

struct FormField<Content: View>: View {
    let label: String
    var error: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(error != nil ? Theme.red : Theme.textSecondary)
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Theme.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error != nil ? Theme.red : Theme.cardBorder, lineWidth: error != nil ? 1.5 : 1)
                )
            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(Theme.red)
            }
        }
    }
}
