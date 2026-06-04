import SwiftUI

/// Single-engine console: live status, lifecycle controls, config inspector,
/// dry-run toggle (PATCH), and broker token update (PUT).
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
            configSection
            tokenSection
        }
        .navigationTitle(vm.engineId)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.refresh(client: appState.client) }
        .refreshable { await vm.refresh(client: appState.client) }
        .overlay(alignment: .bottom) { bannerView }
        .sheet(isPresented: $showTokenSheet) { tokenSheet }
    }

    // MARK: Status

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            switch vm.status {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case .loaded(let e):
                LabeledContent("State") { EngineStatusBadge(state: e.runState) }
                if let broker = e.broker, !broker.isEmpty { LabeledContent("Broker", value: broker.uppercased()) }
                if let strat = e.strategy, !strat.isEmpty { LabeledContent("Strategy", value: strat) }
                if let pid = e.pid { LabeledContent("PID", value: String(pid)) }
                if let beat = e.lastBeat { LabeledContent("Last heartbeat", value: beat) }
            }
        }
    }

    // MARK: Lifecycle controls

    @ViewBuilder
    private var controlsSection: some View {
        Section {
            lifecycleButton(.start, "Start", "play.fill", Theme.profitGreen)
            lifecycleButton(.restart, "Restart", "arrow.clockwise", .blue)
            lifecycleButton(.stop, "Stop", "stop.fill", .orange)
        } header: {
            Text("Controls")
        } footer: {
            if !canWrite { Text("Add your API key in Settings to control this engine.") }
        }
    }

    private func lifecycleButton(_ action: EngineLifecycleAction, _ title: String, _ icon: String, _ tint: Color) -> some View {
        Button {
            Task { await vm.lifecycle(action, client: appState.client) }
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

    // MARK: Config inspector

    @ViewBuilder
    private var configSection: some View {
        Section {
            switch vm.config {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading config…").foregroundStyle(.secondary) }
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case .loaded(let cfg):
                configRows(cfg)
            }
        } header: {
            Text("Configuration")
        } footer: {
            Text("Live YAML config. Toggling dry-run merge-patches the engine; restart to apply.")
        }
    }

    @ViewBuilder
    private func configRows(_ cfg: JSONValue) -> some View {
        // Surface a dry_run toggle if present in params.
        if let dryRun = dryRunValue(in: cfg) {
            Toggle(isOn: Binding(
                get: { dryRun },
                set: { newVal in Task { await vm.patchParam("dry_run", value: .bool(newVal), client: appState.client) } }
            )) {
                Label("Dry run (paper)", systemImage: "testtube.2")
            }
            .disabled(!canWrite || vm.savingConfig)
        }

        ForEach(cfg.sortedObjectRows, id: \.key) { row in
            if case .object(let nested) = row.value {
                DisclosureGroup(row.key) {
                    ForEach(nested.sorted { $0.key < $1.key }, id: \.key) { sub in
                        LabeledContent(sub.key, value: sub.value.displayString)
                            .font(.callout)
                    }
                }
            } else {
                LabeledContent(row.key, value: row.value.displayString)
            }
        }
    }

    private func dryRunValue(in cfg: JSONValue) -> Bool? {
        guard case .object(let root) = cfg,
              case .object(let params)? = root["params"],
              case .bool(let b)? = params["dry_run"] else { return nil }
        return b
    }

    // MARK: Broker token

    @ViewBuilder
    private var tokenSection: some View {
        Section {
            Button {
                tokenInput = ""
                showTokenSheet = true
            } label: {
                Label("Update broker token", systemImage: "key.fill")
            }
            .disabled(!canWrite)
        } footer: {
            Text("Writes the broker access token into the engine's secrets file. Restart to pick it up.")
        }
    }

    private var tokenSheet: some View {
        NavigationStack {
            Form {
                Section("Access token") {
                    TextField("Paste broker access token", text: $tokenInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Update Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showTokenSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await vm.updateToken(tokenInput, client: appState.client) { showTokenSheet = false }
                        }
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
                .font(.caption)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    vm.banner = nil
                }
        }
    }
}
