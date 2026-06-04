import SwiftUI

/// Dashboard-first Home. Answers at a glance: is anything running, which broker,
/// which style, live P&L, and what needs attention — with one obvious next action.
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = HomeVM()
    @Binding var selection: RootTab

    @State private var showCreate = false
    @State private var showSettings = false
    @State private var showDiagnostics = false

    private var brokerConnected: Bool {
        if let tokens = appState.serverStatus?.tokens,
           tokens.values.contains(where: { $0.contains("updated") || $0.contains("loaded") || $0.contains("active") }) {
            return true
        }
        return vm.health?.components?["brokers"]?.level == .healthy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !appState.isOnline {
                        offlineBanner
                    }
                    heroCard
                    HStack(spacing: 12) {
                        livePnlCard
                        brokerCard
                    }
                    ForEach(vm.alerts(brokerConnected: brokerConnected)) { alert in
                        alertCard(alert)
                    }
                    quickActions
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .refreshable { vm.refresh(client: appState.client); await appState.fetchStatus() }
            .task {
                vm.refresh(client: appState.client)
                appState.startPolling()
            }
            .onChange(of: vm.banner) { _, msg in
                if msg != nil { Task { try? await Task.sleep(for: .seconds(4)); vm.banner = nil } }
            }
            .sheet(isPresented: $showCreate) {
                CreateBotWizard { vm.refresh(client: appState.client) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(isPresented: $showDiagnostics) { DiagnosticsView() }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroCard: some View {
        if let bot = vm.primaryBot {
            let isLive = !isPracticeBot(bot)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusChip(status: AppStatus(runState: bot.runState))
                    Spacer()
                    ModeBadge(isPractice: !isLive)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(BotNaming.display(bot.engineId))
                        .font(.title2.bold())
                    Text("\(EngineStrategy.friendlyName(forRaw: bot.strategy)) · \(brokerLabel(bot.broker))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if vm.runningBots.count > 1 {
                    Text("+ \(vm.runningBots.count - 1) more running")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button {
                        Haptics.tap(); selection = .bots
                    } label: {
                        Label("Manage", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        Task { await vm.stopPrimary(client: appState.client) }
                    } label: {
                        HStack {
                            if vm.busyStopId == bot.engineId { ProgressView().controlSize(.small) }
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!appState.hasAPIKey || vm.busyStopId != nil)
                }
            }
            .padding(16)
            .glassCard()
        } else {
            VStack(spacing: 14) {
                Image(systemName: vm.totalBots == 0 ? "sparkles" : "moon.zzz.fill")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                Text(vm.totalBots == 0 ? "No bots yet" : "Nothing running")
                    .font(.title3.weight(.semibold))
                Text(vm.totalBots == 0
                     ? "Create your first bot and try it in Practice mode — no real money."
                     : "Your bots are stopped. Start one whenever you're ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    if vm.totalBots == 0 { showCreate = true } else { selection = .bots }
                } label: {
                    Text(vm.totalBots == 0 ? "Create your first bot" : "Go to Bots")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.totalBots == 0 && !appState.hasAPIKey)
                if vm.totalBots == 0 && !appState.hasAPIKey {
                    Text("Add your admin access code in Settings first.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .glassCard()
        }
    }

    // MARK: Stat cards

    private var livePnlCard: some View {
        let pnl = vm.liveMTM?.mtmInr
        return statCard(title: "Live P&L", systemImage: "indianrupeesign.circle") {
            if let pnl {
                let sign = pnl >= 0 ? "+" : "-"
                Text("\(sign)₹\(Int(abs(pnl)))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(pnl >= 0 ? Theme.profitGreen : Theme.lossRed)
            } else {
                Text(vm.marketOpen == false ? "Market closed" : "No open trades")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var brokerCard: some View {
        statCard(title: "Broker", systemImage: "building.columns") {
            StatusChip(status: brokerConnected ? .connected : .disconnected, compact: true)
        }
    }

    // MARK: Alerts

    @ViewBuilder
    private func alertCard(_ alert: HomeAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: alert.systemImage)
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.subheadline.weight(.semibold))
                Text(alert.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(alert.actionLabel) { handle(alert) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(12)
        .thinGlassCard()
    }

    private func handle(_ alert: HomeAlert) {
        switch alert.kind {
        case .botNotResponding(let id):
            Task { await restart(id) }
        case .brokerDisconnected:
            selection = .more
        case .systemWarning, .systemFailed:
            showDiagnostics = true
        }
    }

    private func restart(_ id: String) async {
        do {
            _ = try await appState.client.engineLifecycle(id, action: .restart)
            Haptics.success()
            vm.refresh(client: appState.client)
        } catch {
            vm.banner = FriendlyError.from(error).message
            Haptics.error()
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction("New bot", "plus.circle.fill", .blue) {
                if appState.hasAPIKey { showCreate = true } else { showSettings = true }
            }
            quickAction("Activity", "chart.line.uptrend.xyaxis", Theme.profitGreen) { selection = .activity }
            quickAction("Checkup", "stethoscope", .purple) { showDiagnostics = true }
        }
    }

    private func quickAction(_ title: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(tint)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .thinGlassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Building blocks

    private func statCard<Content: View>(title: String, systemImage: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(14)
        .glassCard()
    }

    private var offlineBanner: some View {
        Label("You're offline. Showing the last known info.", systemImage: "wifi.slash")
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .thinGlassCard()
    }

    // MARK: Helpers

    private func isPracticeBot(_ bot: EngineInfo) -> Bool {
        // Heartbeat doesn't carry dry_run; default to the safe assumption (Practice)
        // unless the global status says the running engine is live.
        if appState.serverStatus?.isPaperTrading == false { return false }
        return true
    }

    private func brokerLabel(_ raw: String?) -> String {
        guard let raw, let b = EngineBroker(rawValue: raw.lowercased()) else { return (raw ?? "—").capitalized }
        return b.displayName
    }
}

/// Practice / Live badge.
struct ModeBadge: View {
    let isPractice: Bool
    var body: some View {
        Label(isPractice ? "Practice" : "Live",
              systemImage: isPractice ? "testtube.2" : "indianrupeesign.circle.fill")
            .font(.caption.bold())
            .foregroundStyle(isPractice ? .orange : Theme.lossRed)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((isPractice ? Color.orange : Theme.lossRed).opacity(0.15), in: Capsule())
            .accessibilityLabel(isPractice ? "Practice mode" : "Live mode, real money")
    }
}
