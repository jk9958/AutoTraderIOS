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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ENGINE STATUS")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textSecondary)
                        .tracking(0.5)

                    if let engine = status.engine {
                        Text(engine)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                Spacer()

                VStack(spacing: 8) {
                    StatusPill(
                        label: status.running ? "RUNNING" : "STOPPED",
                        color: status.running ? Theme.green : Theme.red
                    )
                    StatusPill(
                        label: status.isPaperTrading ? "PAPER" : "LIVE",
                        color: status.isPaperTrading ? Theme.orange : Theme.red
                    )
                }
            }

            Divider().background(Color.white.opacity(0.1))

            if status.running, let startedAt = status.startedAt {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Started", systemImage: "play.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(formattedStartTime(startedAt))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(Theme.green)
                    }

                    if !elapsed.isEmpty {
                        HStack {
                            Label("Elapsed", systemImage: "hourglass.bottomhalf.fill")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(elapsed)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(Theme.successGreen)
                        }
                    }
                }
                .padding(10)
                .background(Theme.successGreen.opacity(0.1))
                .cornerRadius(10)
                .onReceive(timer) { _ in
                    elapsed = elapsedString(since: startedAt)
                }
                .onAppear {
                    elapsed = elapsedString(since: startedAt)
                }
            }

            if let code = status.exitCode, code != 0, !status.running {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.red)
                    Text("Exit code \(code) — check logs")
                        .font(.caption)
                        .foregroundColor(Theme.red)
                }
                .padding(10)
                .background(Theme.red.opacity(0.15))
                .cornerRadius(10)
            }

            if let err = stopError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(Theme.red)
                    .padding(10)
                    .background(Theme.red.opacity(0.1))
                    .cornerRadius(8)
            }

            LoadingButton(
                "Stop Engine",
                isLoading: isStoppingEngine,
                role: .destructive,
                color: Theme.red,
                action: onStop
            )
            .disabled(!status.running)
            .opacity(status.running ? 1 : 0.5)
        }
        .glassStyle()
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
