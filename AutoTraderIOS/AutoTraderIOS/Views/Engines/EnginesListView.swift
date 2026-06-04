import SwiftUI

/// Multi-engine management home (mobile API v1). Lists every engine with its
/// heartbeat status; supports create, drill-in, swipe-to-stop, and context actions.
struct EnginesListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = EnginesVM()

    @State private var showCreate = false
    @State private var showSettings = false
    @State private var pendingDelete: EngineInfo?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Engines")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreate = true } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(!appState.hasAPIKey)
                    }
                }
                .sheet(isPresented: $showCreate) {
                    CreateEngineView { vm.load(client: appState.client, showSpinner: false) }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .refreshable { vm.load(client: appState.client, showSpinner: false) }
                .task { vm.load(client: appState.client) }
                .onChange(of: vm.banner) { _, msg in
                    if msg != nil { Task { try? await Task.sleep(for: .seconds(4)); vm.banner = nil } }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView("Loading engines…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            ContentUnavailableView {
                Label("Couldn't load engines", systemImage: "exclamationmark.triangle")
            } description: {
                Text(msg)
            } actions: {
                Button("Retry") { vm.load(client: appState.client) }
            }
        case .loaded(let engines):
            engineList(engines)
        }
    }

    @ViewBuilder
    private func engineList(_ engines: [EngineInfo]) -> some View {
        if engines.isEmpty {
            ContentUnavailableView {
                Label("No engines yet", systemImage: "server.rack")
            } description: {
                Text(appState.hasAPIKey
                     ? "Create an engine to start trading a broker × strategy."
                     : "Add your API key in Settings, then create an engine.")
            } actions: {
                if appState.hasAPIKey {
                    Button("Create Engine") { showCreate = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Open Settings") { showSettings = true }
                }
            }
        } else {
            List {
                if let banner = vm.banner {
                    Section {
                        Label(banner, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    ForEach(engines) { engine in
                        NavigationLink(value: engine.engineId) {
                            EngineRow(engine: engine, busy: vm.busy.contains(engine.engineId))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActions(for: engine)
                        }
                        .contextMenu { contextActions(for: engine) }
                    }
                } footer: {
                    Text("Pull to refresh • status from server heartbeat")
                }
            }
            .navigationDestination(for: String.self) { id in
                EngineDetailView(engineId: id)
            }
            .confirmationDialog(
                "Delete engine \(pendingDelete?.engineId ?? "")?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let e = pendingDelete {
                        Task { await vm.delete(e.engineId, client: appState.client) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Stops the engine and removes its config. The secrets file is preserved on the server.")
            }
        }
    }

    @ViewBuilder
    private func swipeActions(for engine: EngineInfo) -> some View {
        if appState.hasAPIKey {
            Button(role: .destructive) { pendingDelete = engine } label: {
                Label("Delete", systemImage: "trash")
            }
            if engine.runState == .running || engine.runState == .stale {
                Button { Task { await vm.perform(.stop, on: engine.engineId, client: appState.client) } } label: {
                    Label("Stop", systemImage: "stop.fill")
                }.tint(.orange)
            } else {
                Button { Task { await vm.perform(.start, on: engine.engineId, client: appState.client) } } label: {
                    Label("Start", systemImage: "play.fill")
                }.tint(Theme.profitGreen)
            }
        }
    }

    @ViewBuilder
    private func contextActions(for engine: EngineInfo) -> some View {
        if appState.hasAPIKey {
            Button { Task { await vm.perform(.start, on: engine.engineId, client: appState.client) } } label: {
                Label("Start", systemImage: "play.fill")
            }
            Button { Task { await vm.perform(.stop, on: engine.engineId, client: appState.client) } } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            Button { Task { await vm.perform(.restart, on: engine.engineId, client: appState.client) } } label: {
                Label("Restart", systemImage: "arrow.clockwise")
            }
            Divider()
            Button(role: .destructive) { pendingDelete = engine } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            Label("Add API key in Settings to control engines", systemImage: "key")
        }
    }
}

/// Single row in the engines list.
struct EngineRow: View {
    let engine: EngineInfo
    let busy: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.engineId)
                    .font(.headline)
                HStack(spacing: 8) {
                    if let broker = engine.broker, !broker.isEmpty {
                        Text(broker.uppercased())
                    }
                    if let strat = engine.strategy, !strat.isEmpty {
                        Text("• \(strat)")
                    }
                    if let pid = engine.pid {
                        Text("• pid \(pid)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if busy {
                ProgressView()
            } else {
                EngineStatusBadge(state: engine.runState)
            }
        }
        .padding(.vertical, 4)
    }
}
