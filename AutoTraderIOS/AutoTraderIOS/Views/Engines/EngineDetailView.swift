import SwiftUI

/// Single-bot console: status, start/stop/restart, Practice-mode toggle (PATCH),
/// broker login update (PUT), advanced config, and delete. Plain language throughout.
struct EngineDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: EngineDetailVM

    @State private var showTokenSheet = false
    @State private var tokenInput = ""

    init(engineId: String) {
        _vm = StateObject(wrappedValue: EngineDetailVM(engineId: engineId))
    }

    private var canWrite: Bool { appState.hasAPIKey }

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
            lifecycleButton(.start, "Start", "play.fill", Theme.profitGreen)
            lifecycleButton(.restart, "Restart", "arrow.clockwise", .blue)
            lifecycleButton(.stop, "Stop", "stop.fill", .orange)
        } header: {
            Text("Controls")
        } footer: {
            if !canWrite { Text("Add your admin access code in Settings to control this bot.") }
        }
    }

    private func lifecycleButton(_ action: EngineLifecycleAction, _ title: String, _ icon: String, _ tint: Color) -> some View {
        Button {
            Task {
                await vm.lifecycle(action, client: appState.client)
                if action == .start { Analytics.shared.track(.botStarted(live: false)) }
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
                        set: { newVal in Task { await vm.patchParam("dry_run", value: .bool(newVal), client: appState.client) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Practice mode")
                            Text(dryRun ? "No real money." : "⚠️ Live — real money.")
                                .font(.caption).foregroundStyle(dryRun ? .secondary : Theme.lossRed)
                        }
                    }
                    .disabled(!canWrite || vm.savingConfig)
                }
                Button { tokenInput = ""; showTokenSheet = true } label: {
                    Label("Update broker login", systemImage: "key.fill")
                }
                .disabled(!canWrite)

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
            Text("Changing Practice mode updates the bot. Restart it for the change to take effect.")
        }
    }

    private func dryRunValue(in cfg: JSONValue) -> Bool? {
        guard case .object(let root) = cfg,
              case .object(let params)? = root["params"],
              case .bool(let b)? = params["dry_run"] else { return nil }
        return b
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
