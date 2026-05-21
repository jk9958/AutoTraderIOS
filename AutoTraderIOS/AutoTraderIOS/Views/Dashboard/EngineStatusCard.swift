import SwiftUI
import Combine

struct EngineStatusCard: View {
    let status: ServerStatus
    let isStoppingEngine: Bool
    let stopError: String?
    let onStop: () -> Void

    @State private var elapsed = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Engine")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                StatusPill(
                    label: status.running ? "RUNNING" : "STOPPED",
                    color: status.running ? Theme.green : Theme.textSecondary
                )
                StatusPill(
                    label: status.isPaperTrading ? "PAPER" : "LIVE",
                    color: status.isPaperTrading ? Theme.orange : Theme.red
                )
            }

            if let engine = status.engine {
                Text(engine)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            if status.running, let startedAt = status.startedAt {
                HStack {
                    Text("Started:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(formattedStartTime(startedAt))
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if !elapsed.isEmpty {
                        Text(elapsed)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Theme.green)
                    }
                }
                .onReceive(timer) { _ in
                    elapsed = elapsedString(since: startedAt)
                }
                .onAppear {
                    elapsed = elapsedString(since: startedAt)
                }
            }

            if let code = status.exitCode, code != 0, !status.running {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.red)
                    Text("Engine exited with code \(code). Check logs.")
                        .font(.caption)
                        .foregroundColor(Theme.red)
                }
                .padding(8)
                .background(Theme.red.opacity(0.15))
                .cornerRadius(8)
            }

            if let err = stopError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(Theme.red)
            }

            LoadingButton(
                "Stop Engine",
                isLoading: isStoppingEngine,
                role: .destructive,
                color: Theme.red,
                action: onStop
            )
            .disabled(!status.running)
            .opacity(status.running ? 1 : 0.4)
        }
        .cardStyle()
    }

    private func formattedStartTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateFormat = "HH:mm:ss"
            return out.string(from: date)
        }
        return iso
    }

    private func elapsedString(since iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let start = formatter.date(from: iso) else { return "" }
        let secs = Int(-start.timeIntervalSinceNow)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        return String(format: "%dm %02ds", m, s)
    }
}
