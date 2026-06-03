import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardVM()
    @State private var showSettings = false
    @State private var elapsed = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var status: ServerStatus? { appState.serverStatus }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if appState.connectionState == .disconnected, let err = appState.connectionError {
                        ConnectionBannerCard(message: err) { appState.refreshNow() }
                    }

                    if let s = status {
                        EngineCard(
                            s: s,
                            elapsed: elapsed,
                            formattedStartTime: formattedStartTime(_:),
                            stopError: vm.stopError,
                            isStopping: vm.isStoppingEngine,
                            onStop: { Task { await vm.stopEngine(appState: appState) } }
                        )
                        BrokerAuthCard(
                            status: s,
                            isSavingFyers: vm.isSavingFyersToEnv,
                            onFyers:      { vm.openFyersAuth(appState: appState) },
                            onKite:       { vm.openKiteAuth(appState: appState) },
                            onTradesmart: { vm.openTradesmartAuth(appState: appState) },
                            onSaveFyers:  { Task { await vm.saveFyersToEnv(appState: appState) } }
                        )
                    } else {
                        ConnectingCard(state: appState.connectionState)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable { await appState.fetchStatus() }
            .navigationTitle("Auto Trader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .symbolVariant(.fill)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $vm.showFyersAuth) {
                if let url = vm.fyersAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleFyersAuthDismiss(appState: appState) } }
                }
            }
            .sheet(isPresented: $vm.showKiteAuth) {
                if let url = vm.kiteAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleKiteAuthDismiss(appState: appState) } }
                }
            }
            .sheet(isPresented: $vm.showTradesmartAuth) {
                if let url = vm.tradesmartAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleTradesmartAuthDismiss(appState: appState) } }
                }
            }
            .alert(vm.alertMessage ?? "", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                elapsed = elapsedIfRunning()
                appState.startPolling()
                appState.refreshNow()
            }
            .onDisappear { appState.stopPolling() }
            .onReceive(timer) { _ in elapsed = elapsedIfRunning() }
        }
    }

    private func elapsedIfRunning() -> String {
        guard let s = status, s.running, let startedAt = s.startedAt else { return "" }
        return elapsedString(since: startedAt)
    }

    private func formattedStartTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm:ss"
        return out.string(from: date)
    }

    private func elapsedString(since iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let start = f.date(from: iso) else { return "" }
        let secs = Int(-start.timeIntervalSinceNow)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        return String(format: "%dm %02ds", m, s)
    }
}

// MARK: - Engine Card

private struct EngineCard: View {
    let s: ServerStatus
    let elapsed: String
    let formattedStartTime: (String) -> String
    let stopError: String?
    let isStopping: Bool
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status header
            HStack(alignment: .top, spacing: 12) {
                PulsingDot(active: s.running)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.running ? "Engine Running" : "Engine Stopped")
                        .font(.headline)
                    if let engine = s.engine, !engine.isEmpty {
                        Text(engine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                TradingModeBadge(isPaper: s.isPaperTrading)
            }
            .padding(16)

            // Uptime strip
            if s.running, let startedAt = s.startedAt {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 24) {
                    MetricLabel("Started", value: formattedStartTime(startedAt))
                    if !elapsed.isEmpty {
                        MetricLabel("Uptime", value: elapsed, valueColor: .green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Exit warning
            if let code = s.exitCode, code != 0, !s.running {
                Divider().padding(.horizontal, 16)
                Label("Exit code \(code) — check logs", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            // Stop button
            if s.running {
                Divider().padding(.horizontal, 16)
                if let err = stopError {
                    Label(err, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
                Button(action: onStop) {
                    HStack(spacing: 6) {
                        if isStopping {
                            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8)
                        }
                        Text(isStopping ? "Stopping…" : "Stop Engine")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isStopping)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .glassCard()
    }
}

// MARK: - Broker Auth Card

private struct BrokerAuthCard: View {
    let status: ServerStatus
    let isSavingFyers: Bool
    let onFyers: () -> Void
    let onKite: () -> Void
    let onTradesmart: () -> Void
    let onSaveFyers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Broker Auth")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Token status chips
            HStack(spacing: 10) {
                BrokerChip("Fyers",      status: status.tokens?["fyers"])
                BrokerChip("Kite",       status: status.tokens?["kite"])
                BrokerChip("TradeSmart", status: status.tokens?["tradesmart"])
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            // Login buttons
            VStack(spacing: 0) {
                AuthRow(label: "Login with Fyers",      icon: "arrow.up.right.square.fill", tint: .blue,   action: onFyers)
                Divider().padding(.leading, 52)
                AuthRow(label: "Login with Kite",       icon: "arrow.up.right.square.fill", tint: .purple, action: onKite)
                Divider().padding(.leading, 52)
                AuthRow(label: "Login with TradeSmart", icon: "arrow.up.right.square.fill", tint: .indigo, action: onTradesmart)
                Divider().padding(.leading, 52)
                AuthRow(
                    label: isSavingFyers ? "Saving…" : "Save Fyers Token to .env",
                    icon: "square.and.arrow.down.fill",
                    tint: .green,
                    trailing: isSavingFyers ? AnyView(ProgressView().scaleEffect(0.8)) : AnyView(EmptyView()),
                    action: onSaveFyers
                )
            }
            .padding(.bottom, 4)
        }
        .glassCard()
    }
}

// MARK: - Subcomponents

private struct PulsingDot: View {
    let active: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if active {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                    .onAppear { pulse = true }
            }
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 10, height: 10)
        }
    }
}

private struct TradingModeBadge: View {
    let isPaper: Bool
    var body: some View {
        Text(isPaper ? "Paper" : "Live")
            .font(.caption.bold())
            .foregroundStyle(isPaper ? .orange : .red)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((isPaper ? Color.orange : Color.red).opacity(0.15))
            )
    }
}

private struct MetricLabel: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    init(_ title: String, value: String, valueColor: Color = .primary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }
}

private struct BrokerChip: View {
    let label: String
    let status: String?

    init(_ label: String, status: String?) {
        self.label = label
        self.status = status
    }

    private var isReady: Bool {
        let v = status ?? ""
        return v.contains("updated") || v.contains("loaded") || v.contains("active")
    }

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title3)
                .foregroundStyle(isReady ? .green : .secondary)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isReady ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isReady ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
        )
    }
}

private struct AuthRow: View {
    let label: String
    let icon: String
    let tint: Color
    var trailing: AnyView = AnyView(Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.secondary.opacity(0.5)))
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.body)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Connecting / Error Cards

private struct ConnectingCard: View {
    let state: ConnectionState
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text(state == .disconnected ? "Retrying connection…" : "Connecting to server…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .glassCard()
    }
}

private struct ConnectionBannerCard: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Error")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry", action: onRetry)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.orange)
        }
        .padding(12)
        .thinGlassCard()
    }
}
