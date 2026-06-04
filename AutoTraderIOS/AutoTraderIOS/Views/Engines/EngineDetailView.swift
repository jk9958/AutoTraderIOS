import SwiftUI

/// Single-bot console: status, start/stop/restart, Practice-mode toggle (PATCH),
/// broker login (one-tap OAuth for any broker → server-side token sync, or manual
/// paste as a fallback), advanced config, and delete. Plain language throughout.
struct EngineDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: EngineDetailVM

    @State private var showTokenSheet = false
    @State private var tokenInput = ""
    @State private var showBrokerAuth = false
    @State private var brokerAuthURL: URL?
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
        .toast($vm.toast)
        .sheet(isPresented: $showTokenSheet) { tokenSheet }
        .sheet(isPresented: $showBrokerAuth) {
            if let url = brokerAuthURL {
                SafariView(url: url).ignoresSafeArea()
                    .onDisappear { Task { await finishReconnect() } }
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
            Text("Reconnect logs in with \(botBroker.displayName) and updates this bot automatically. Broker logins expire daily — restart the bot after reconnecting.")
        }
    }

    private func dryRunValue(in cfg: JSONValue) -> Bool? {
        guard case .object(let root) = cfg,
              case .object(let params)? = root["params"],
              case .bool(let b)? = params["dry_run"] else { return nil }
        return b
    }

    // MARK: Broker login (one-tap OAuth → server-side token sync, any broker)

    @ViewBuilder
    private var brokerLoginRows: some View {
        if reconnecting {
            HStack { ProgressView(); Text("Reconnecting…").foregroundStyle(.secondary) }
        } else {
            Button { startReconnect() } label: {
                Label("Reconnect \(botBroker.displayName)", systemImage: "arrow.clockwise.circle.fill")
            }
            .disabled(!canWrite)
            Button { tokenInput = ""; showTokenSheet = true } label: {
                Label("Paste token instead", systemImage: "key")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .disabled(!canWrite)
        }
    }

    private func makeBrokerAuthURL() throws -> URL {
        switch botBroker {
        case .fyers:      return try appState.client.fyersAuthURL()
        case .kite:       return try appState.client.kiteAuthURL()
        case .tradesmart: return try appState.client.tradesmartAuthURL()
        }
    }

    private func startReconnect() {
        do {
            brokerAuthURL = try makeBrokerAuthURL()
            showBrokerAuth = true
        } catch {
            vm.toast = .error(FriendlyError.from(error).message)
        }
    }

    /// After the broker web login closes, ask the server to copy its now-current
    /// token into THIS bot's secrets (no token crosses the wire).
    private func finishReconnect() async {
        reconnecting = true
        defer { reconnecting = false }
        await appState.fetchStatus()   // let the server settle the new login
        do {
            _ = try await appState.client.syncEngineToken(vm.engineId)
            appState.enginesStore.invalidate(vm.engineId)
            Analytics.shared.track(.brokerConnected(broker: botBroker.rawValue))
            await vm.refresh(client: appState.client)
            reconnectInfo = "\(botBroker.displayName) reconnected for this bot. Restart it to use the new login."
        } catch {
            reconnectInfo = FriendlyError.from(error).message
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
