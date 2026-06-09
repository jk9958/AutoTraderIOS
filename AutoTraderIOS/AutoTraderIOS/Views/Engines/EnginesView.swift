import SwiftUI

struct EnginesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = EnginesVM()
    @State private var showLaunch = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.engines.isEmpty && vm.isLoading {
                    ProgressView("Loading engines…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.engines.isEmpty {
                    emptyState
                } else {
                    List {
                        if let err = vm.loadError {
                            Section { Text(err).font(.caption).foregroundStyle(.red) }
                        }
                        Section {
                            ForEach(vm.engines) { engine in
                                EngineRow(
                                    engine: engine,
                                    isStopping: vm.stoppingIds.contains(engine.engineId),
                                    onStop: { Task { await vm.stopEngine(engine, appState: appState) } }
                                )
                            }
                        } header: {
                            Text("Running engines")
                        }
                    }
                }
            }
            .navigationTitle("Engines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLaunch = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await vm.reload(appState: appState) }
            .sheet(isPresented: $showLaunch) {
                LaunchSheet { Task { await vm.reload(appState: appState) } }
                    .environmentObject(appState)
            }
            .task { vm.start(appState: appState) }
            .onDisappear { vm.stop() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No engines running", systemImage: "cpu")
        } description: {
            Text("Launch a strategy to start trading.")
        } actions: {
            Button("Launch Engine") { showLaunch = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct EngineRow: View {
    let engine: EngineHeartbeat
    let isStopping: Bool
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(engine.engineId)
                    .font(.headline)
                Spacer()
                EngineStatePill(state: engine.state)
            }
            HStack(spacing: 8) {
                if let s = engine.strategy { badge(s, color: Theme.blue) }
                if let b = engine.broker { badge(b, color: .purple) }
                if engine.dryRun == true { badge("PRACTICE", color: Theme.orange) }
            }
            HStack {
                if let pid = engine.pid {
                    Label("PID \(pid)", systemImage: "number")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let beat = engine.lastBeat {
                    Label(beat, systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    onStop()
                } label: {
                    if isStopping { ProgressView() } else { Text("Stop") }
                }
                .buttonStyle(.bordered)
                .disabled(isStopping || engine.state == .stopped)
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

struct EngineStatePill: View {
    let state: EngineState

    var body: some View {
        Text(state.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch state {
        case .running: return Theme.green
        case .stale: return Theme.orange
        case .stopped: return Theme.textSecondary
        }
    }
}
