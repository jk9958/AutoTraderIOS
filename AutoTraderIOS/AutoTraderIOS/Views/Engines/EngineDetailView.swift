import SwiftUI

/// Single-bot console: status, start/stop/restart, Practice-mode toggle (PATCH),
/// broker login (one-tap Fyers OAuth that auto-fills the bot's token, or manual
/// paste for other brokers), advanced config, and delete. Plain language throughout.
struct EngineDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: EngineDetailVM

    @State private var showTokenSheet = false
    @State private var tokenInput = ""
    @State private var showFyersAuth = false
    @State private var fyersAuthURL: URL?
    @State private var reconnecting = false
    @State private var reconnectInfo: String?
    @State private var confirmStart = false

    init(engineId: String) {
        _vm = StateObject(wrappedValue: EngineDetailVM(engineId: engineId))
    }

    private var canWrite: Bool { appState.hasAPIKey }

    /// The broker this bot uses (drives whether one-tap OAuth reconnect is offered).
    private var botBroker: EngineBroker {
        EngineBroker(rawValue: (vm.status.value?.broker ?? "").lowercased()) ?? .fyers
    }

    var body: some View {
        List {
            statusSection
            controlsSection
            settingsSection
            aboutSection
        }
        .navigationTitle(BotNaming.display(vm.engineId))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.refresh(client: appState.client) }
        .refreshable { await vm.refresh(client: appState.client) }
        .overlay(alignment: .bottom) { bannerView }
        .sheet(isPresented: $showTokenSheet) { tokenSheet }
        .sheet(isPresented: $showFyersAuth) {
            if let url = fyersAuthURL {
                SafariView(url: url).ignoresSafeArea()
                    .onDisappear { Task { await finishFyersReconnect() } }
            }
        }
        .alert("Broker login", isPresented: Binding(get: { reconnectInfo != nil }, set: { if !$0 { reconnectInfo = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(reconnectInfo ?? "") }
    }

    // MARK: Status

    @ViewBuilder
    private var statusSection: some View {
        Section {
            switch vm.status {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case .loaded(let e):
                LabeledContent("Status") { StatusChip(status: AppStatus(runState: e.runState)) }
                if let broker = e.broker, !broker.isEmpty { LabeledContent("Broker", value: broker.capitalized) }
                if let strat = e.strategy, !strat.isEmpty {
                    LabeledContent("Style", value: EngineStrategy.friendlyName(forRaw: strat))
                }
                if let beat = e.lastBeat { LabeledContent("Last seen", value: relativeBeat(beat)) }
            }
        } footer: {
            Text("“Last seen” is when the bot last checked in. If it says it isn't responding, try Restart.")
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controlsSection: some View {
        Section {
            startButton
            lifecycleButton(.restart, "Restart", "arrow.clockwise", .blue)
            lifecycleButton(.stop, "Stop", "stop.fill", .orange)
        } header: {
            Text("Controls")
        } footer: {
            if !canWrite { Text("Add your admin access code in Settings to control this bot.") }
        }
        .confirmationDialog("Broker not connected", isPresented: $confirmStart, titleVisibility: .visible) {
            Button("Start anyway", role: .destructive) { Task { await doStart() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This bot is in Live mode but \(botBroker.displayName) isn't connected, so live trades may fail. Connect the broker first (Reconnect below), or start anyway.")
        }
    }

    private var startButton: some View {
        Button {
            if isLiveMode && !brokerConnected { confirmStart = true }
            else { Task { await doStart() } }
        } label: {
            HStack {
                Label("Start", systemImage: "play.fill")
                Spacer()
                if vm.busyAction == .start { ProgressView() }
            }
        }
        .tint(Theme.profitGreen)
        .disabled(!canWrite || vm.busyAction != nil)
    }

    private func doStart() async {
        await vm.lifecycle(.start, client: appState.client)
        appState.enginesStore.invalidate(vm.engineId)
        Analytics.shared.track(.botStarted(live: isLiveMode))
    }

    private func lifecycleButton(_ action: EngineLifecycleAction, _ title: String, _ icon: String, _ tint: Color) -> some View {
        Button {
            Task {
                await vm.lifecycle(action, client: appState.client)
                appState.enginesStore.invalidate(vm.engineId)   // keep Home/Bots in sync
            }
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if vm.busyAction == action { ProgressView() }
            }
        }
        .tint(tint)
        .disabled(!canWrite || vm.busyAction != nil)
    }

    /// Live = the bot's `dry_run` is false. Unknown defaults to Practice (no warning).
    private var isLiveMode: Bool {
        if case .loaded(let cfg) = vm.config, let dry = dryRunValue(in: cfg) { return !dry }
        if let dry = appState.enginesStore.mode(for: vm.engineId) { return !dry }
        return false
    }

    /// Whether the bot's broker currently has a live login on the server.
    private var brokerConnected: Bool {
        let v = appState.serverStatus?.tokens?[botBroker.rawValue] ?? ""
        return v.contains("active") || v.contains("loaded") || v.contains("updated")
    }

    // MARK: Settings (Practice toggle + token + advanced)

    @ViewBuilder
    private var settingsSection: some View {
        Section {
            switch vm.config {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading settings…").foregroundStyle(.secondary) }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case .loaded(let cfg):
                if let dryRun = dryRunValue(in: cfg) {
                    Toggle(isOn: Binding(
                        get: { dryRun },
                        set: { newVal in Task {
                            await vm.patchParam("dry_run", value: .bool(newVal), client: appState.client)
                            appState.enginesStore.invalidate(vm.engineId)   // mode changed → re-sync
                        } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Practice mode")
                            Text(dryRun ? "No real money." : "⚠️ Live — real money.")
                                .font(.caption).foregroundStyle(dryRun ? .secondary : Theme.lossRed)
                        }
                    }
                    .disabled(!canWrite || vm.savingConfig)
                }
                brokerLoginRows

                DisclosureGroup("Advanced details") {
                    ForEach(cfg.sortedObjectRows, id: \.key) { row in
                        if case .object(let nested) = row.value {
                            ForEach(nested.sorted { $0.key < $1.key }, id: \.key) { sub in
                                LabeledContent(sub.key, value: sub.value.displayString).font(.callout)
                            }
                        } else {
                            LabeledContent(row.key, value: row.value.displayString).font(.callout)
                        }
                    }
                }
            }
        } header: {
            Text("Settings")
        } footer: {
            Text(botBroker == .fyers
                 ? "Reconnect logs in with Fyers and updates this bot automatically. Restart the bot for changes to take effect."
                 : "Broker logins expire daily. Update the login, then restart the bot.")
        }
    }

    private func dryRunValue(in cfg: JSONValue) -> Bool? {
        guard case .object(let root) = cfg,
              case .object(let params)? = root["params"],
              case .bool(let b)? = params["dry_run"] else { return nil }
        return b
    }

    // MARK: Broker login (one-tap OAuth for Fyers, manual paste otherwise)

    @ViewBuilder
    private var brokerLoginRows: some View {
        if reconnecting {
            HStack { ProgressView(); Text("Reconnecting…").foregroundStyle(.secondary) }
        } else if botBroker == .fyers {
            Button { startFyersReconnect() } label: {
                Label("Reconnect with Fyers", systemImage: "arrow.clockwise.circle.fill")
            }
            .disabled(!canWrite)
            Button { tokenInput = ""; showTokenSheet = true } label: {
                Label("Paste token instead", systemImage: "key")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .disabled(!canWrite)
        } else {
            Button { tokenInput = ""; showTokenSheet = true } label: {
                Label("Update broker login", systemImage: "key.fill")
            }
            .disabled(!canWrite)
        }
    }

    private func startFyersReconnect() {
        do {
            fyersAuthURL = try appState.client.fyersAuthURL()
            showFyersAuth = true
        } catch {
            vm.banner = FriendlyError.from(error).message
        }
    }

    /// After the Fyers web login closes, read the fresh token from /status and
    /// write it into THIS bot's secrets (the bot reads its own secrets file).
    private func finishFyersReconnect() async {
        reconnecting = true
        defer { reconnecting = false }
        await appState.fetchStatus()
        let token = appState.serverStatus?.fyersAccessToken ?? ""
        guard !token.isEmpty else {
            reconnectInfo = "The Fyers login didn't finish. Please try again."
            return
        }
        if await vm.updateToken(token, client: appState.client) {
            appState.enginesStore.invalidate(vm.engineId)
            Analytics.shared.track(.brokerConnected(broker: "fyers"))
            await vm.refresh(client: appState.client)
            reconnectInfo = "Fyers reconnected for this bot. Restart it to use the new login."
        }
    }

    // MARK: About + delete

    private var aboutSection: some View {
        Section("About this bot") {
            if case .loaded(let e) = vm.status, let strat = e.strategy,
               let s = EngineStrategy(rawValue: strat) {
                Text(s.subtitle).font(.callout).foregroundStyle(.secondary)
            }
            LabeledContent("ID", value: vm.engineId).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Token sheet

    private var tokenSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste broker login token", text: $tokenInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                } footer: {
                    Text("Broker logins expire daily. Paste a fresh token, then restart the bot.")
                }
            }
            .navigationTitle("Broker login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showTokenSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { if await vm.updateToken(tokenInput, client: appState.client) { showTokenSheet = false } }
                    }
                    .disabled(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.savingToken)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Banner

    @ViewBuilder
    private var bannerView: some View {
        if let banner = vm.banner {
            Text(banner)
                .font(.caption).foregroundStyle(.white)
                .padding(12).frame(maxWidth: .infinity)
                .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task { try? await Task.sleep(for: .seconds(4)); vm.banner = nil }
        }
    }

    private func relativeBeat(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "\(max(secs, 0))s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}
