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
    @State private var showBrokers = false

    private var store: EnginesStore { appState.enginesStore }

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
                    if !appState.isOnline { offlineBanner }
                    heroSection
                    HStack(spacing: 12) { livePnlCard; brokerCard }
                    let engines = store.engines
                    ForEach(vm.alerts(engines: engines, brokerConnected: brokerConnected)) { alert in
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
            .refreshable { await store.refresh(); await vm.refreshAux(client: appState.client); await appState.fetchStatus() }
            .task {
                appState.startPolling()                  // app-scoped (also polls the store)
                vm.startAuxPolling(client: appState.client)
            }
            .onDisappear { vm.stopAuxPolling() }
            .onChange(of: vm.banner) { _, msg in
                if msg != nil { Task { try? await Task.sleep(for: .seconds(4)); vm.banner = nil } }
            }
            .sheet(isPresented: $showCreate) {
                CreateBotWizard { Task { await store.refresh() } }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showBrokers) { BrokersView() }
            .navigationDestination(isPresented: $showDiagnostics) { DiagnosticsView() }
        }
    }

    // MARK: Hero (handles loading / failed / empty / running)

    @ViewBuilder
    private var heroSection: some View {
        switch store.state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Checking your bots…").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(36).glassCard()
        case .failed(let msg):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 34)).foregroundStyle(.orange)
                Text("Couldn't load your bots").font(.headline)
                Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Try Again") { Task { await store.refresh(showSpinner: true) } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity).padding(24).glassCard()
        case .loaded(let engines):
            if let bot = vm.primaryBot(engines) {
                runningHero(bot, runningCount: vm.runningBots(engines).count)
            } else {
                emptyHero(totalBots: engines.count)
            }
        }
    }

    private func runningHero(_ bot: EngineInfo, runningCount: Int) -> some View {
        let practice = store.mode(for: bot.engineId)   // real dry_run, nil = unknown
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                StatusChip(status: AppStatus(runState: bot.runState))
                Spacer()
                ModeBadge(isPractice: practice)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(BotNaming.display(bot.engineId)).font(.title2.bold())
                Text("\(EngineStrategy.friendlyName(forRaw: bot.strategy)) · \(brokerLabel(bot.broker))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if runningCount > 1 {
                Text("+ \(runningCount - 1) more running").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button { Haptics.tap(); selection = .bots } label: {
                    Label("Open", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    Task { await vm.stop(bot, store: store) }
                } label: {
                    HStack {
                        if vm.busyStopId == bot.engineId { ProgressView().controlSize(.small) }
                        Label("Stop", systemImage: "stop.fill")
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.red)
                .disabled(!appState.hasAPIKey || vm.busyStopId != nil)
            }
        }
        .padding(16).glassCard()
    }

    private func emptyHero(totalBots: Int) -> some View {
        VStack(spacing: 14) {
            Image(systemName: totalBots == 0 ? "sparkles" : "moon.zzz.fill")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text(totalBots == 0 ? "No bots yet" : "Nothing running")
                .font(.title3.weight(.semibold))
            Text(totalBots == 0
                 ? "Create your first bot and try it in Practice mode — no real money."
                 : "Your bots are stopped. Start one whenever you're ready.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                if totalBots == 0 { showCreate = true } else { selection = .bots }
            } label: {
                Text(totalBots == 0 ? "Create your first bot" : "Go to Bots").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(totalBots == 0 && !appState.hasAPIKey)
            if totalBots == 0 && !appState.hasAPIKey {
                Text("Add your admin access code in Settings first.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity).padding(24).glassCard()
    }

    // MARK: Stat cards

    private var livePnlCard: some View {
        // NOTE: /mtm is the MAIN (default iron-condor) engine's open position only —
        // it does NOT include bots created via the mobile API. Labelled accordingly
        // so it isn't read as the featured bot's P&L.
        let pnl = vm.liveMTM?.mtmInr
        return statCard(title: "Open P&L", systemImage: "indianrupeesign.circle") {
            if let pnl {
                VStack(alignment: .leading, spacing: 2) {
                    let sign = pnl >= 0 ? "+" : "-"
                    Text("\(sign)₹\(Int(abs(pnl)))")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(pnl >= 0 ? Theme.profitGreen : Theme.lossRed)
                    Text("Main account")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                Text(vm.marketOpen == false ? "Market closed" : "No open trades")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var brokerCard: some View {
        Button { Haptics.tap(); showBrokers = true } label: {
            statCard(title: "Broker", systemImage: "building.columns") {
                StatusChip(status: brokerConnected ? .connected : .disconnected, compact: true)
                Text(brokerConnected ? "Tap to manage" : "Tap to connect")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens broker connection")
    }

    // MARK: Alerts

    @ViewBuilder
    private func alertCard(_ alert: HomeAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: alert.systemImage).font(.title3).foregroundStyle(.orange).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.subheadline.weight(.semibold))
                Text(alert.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(alert.actionLabel) { handle(alert) }
                .font(.caption.weight(.semibold)).buttonStyle(.bordered)
        }
        .padding(12).thinGlassCard()
    }

    private func handle(_ alert: HomeAlert) {
        switch alert.kind {
        case .botNotResponding(let id): Task { await vm.restart(id, store: store) }
        case .brokerDisconnected:       showBrokers = true
        case .systemWarning, .systemFailed: showDiagnostics = true
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
            .frame(maxWidth: .infinity).padding(.vertical, 16).thinGlassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Building blocks

    private func statCard<Content: View>(title: String, systemImage: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(14).glassCard()
    }

    private var offlineBanner: some View {
        Label("You're offline. Showing the last known info.", systemImage: "wifi.slash")
            .font(.caption.weight(.medium)).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).thinGlassCard()
    }

    private func brokerLabel(_ raw: String?) -> String {
        guard let raw, let b = EngineBroker(rawValue: raw.lowercased()) else { return (raw ?? "—").capitalized }
        return b.displayName
    }
}

/// Practice / Live badge. `nil` = mode not yet known (shows a neutral chip rather
/// than guessing, since this gates a real-money signal).
struct ModeBadge: View {
    let isPractice: Bool?
    var body: some View {
        let (text, color, icon): (String, Color, String) = {
            switch isPractice {
            case .some(true):  return ("Practice", .orange, "testtube.2")
            case .some(false): return ("Live", Theme.lossRed, "indianrupeesign.circle.fill")
            case .none:        return ("Mode…", .secondary, "questionmark.circle")
            }
        }()
        return Label(text, systemImage: icon)
            .font(.caption.bold()).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch isPractice {
        case .some(true):  return "Practice mode"
        case .some(false): return "Live mode, real money"
        case .none:        return "Mode unknown, checking"
        }
    }
}
