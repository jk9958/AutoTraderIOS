import SwiftUI

struct EngineStatusCard: View {
    let status: ServerStatus
    @Binding var showStopConfirmation: Bool
    let isStoppingEngine: Bool

    @State private var elapsed: String = ""
    @State private var elapsedTimer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                Text("Engine Status")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                StatusPill(
                    label: status.running ? "Running" : "Stopped",
                    color: status.running ? Theme.green : Color(hex: "555558")
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(Theme.divider)

            // PAPER / LIVE full-width banner
            TradingModeBanner(isLive: status.isLive)

            // Engine details
            if let engine = status.engine {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Text(engine)
                        .font(.subheadline)
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Start time + elapsed
            if let startTime = status.formattedStartTime {
                HStack(spacing: 16) {
                    Label(startTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if status.running && !elapsed.isEmpty {
                        Label(elapsed, systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }

            // Exit code warning
            if let code = status.exitCode, code != 0, !status.running {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.orange)
                        .font(.system(size: 13))
                    Text("Engine exited with code \(code) — check logs.")
                        .font(.caption)
                        .foregroundColor(Theme.orange)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)
            }

            Divider()
                .background(Theme.divider)
                .padding(.top, 12)

            // Stop button
            LoadingButton(
                title: isStoppingEngine ? "Stopping..." : "Stop Engine",
                icon: "stop.fill",
                color: Theme.red,
                isLoading: isStoppingEngine,
                isDisabled: !status.running
            ) {
                showStopConfirmation = true
            }
            .padding(16)
        }
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .onAppear { startElapsedTimer() }
        .onDisappear { stopElapsedTimer() }
        .onChange(of: status.startedAt) { _ in
            startElapsedTimer()
        }
    }

    private func startElapsedTimer() {
        elapsed = status.elapsed()
        guard status.running else { return }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.elapsed = status.elapsed()
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
}

private struct TradingModeBanner: View {
    let isLive: Bool

    var body: some View {
        HStack {
            Image(systemName: isLive ? "exclamationmark.triangle.fill" : "doc.text.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(isLive ? "LIVE TRADING — Real orders will be placed" : "PAPER TRADING — Simulation only")
                .font(.subheadline.weight(.bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isLive ? Theme.red : Theme.orange)
    }
}
