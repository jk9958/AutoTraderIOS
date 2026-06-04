import SwiftUI

/// Novice-facing list of trading bots (multi-engine mobile API). Reads the shared
/// `EnginesStore` so it always agrees with Home. Plain language, swipe to
/// start/stop, context menu for more, and a guided create flow.
struct BotsListView: View {
    @EnvironmentObject var appState: AppState

    @State private var showCreate = false
    @State private var showSettings = false
    @State private var pendingDelete: EngineInfo?
    @State private var searchText = ""

    private var store: EnginesStore { appState.enginesStore }

    private var filtered: [EngineInfo] {
        let all = store.engines
        guard !searchText.isEmpty else { return all }
        return all.filter {
            BotNaming.display($0.engineId).localizedCaseInsensitiveContains(searchText) ||
            ($0.strategy ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bots")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreate = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Create a bot")
                            .disabled(!appState.hasAPIKey)
                    }
                }
                .sheet(isPresented: $showCreate) {
                    CreateBotWizard { Task { await store.refresh() } }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .refreshable { await store.refresh() }
                .task { await store.refresh(showSpinner: true) }
                .onChange(of: store.banner) { _, msg in
                    if msg != nil { Task { try? await Task.sleep(for: .seconds(4)); store.banner = nil } }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView("Loading your bots…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            ContentUnavailableView {
                Label("Couldn't load your bots", systemImage: "exclamationmark.triangle")
            } description: { Text(msg) } actions: {
                Button("Try Again") { Task { await store.refresh(showSpinner: true) } }
            }
        case .loaded(let engines):
            list(engines)
        }
    }

    @ViewBuilder
    private func list(_ engines: [EngineInfo]) -> some View {
        if engines.isEmpty {
            ContentUnavailableView {
                Label("No bots yet", systemImage: "server.rack")
            } description: {
                Text(appState.hasAPIKey
                     ? "Create your first bot and try it in Practice mode — no real money involved."
                     : "Add your admin access code in Settings, then create your first bot.")
            } actions: {
                if appState.hasAPIKey {
                    Button("Create a bot") { showCreate = true }.buttonStyle(.borderedProminent)
                } else {
                    Button("Open Settings") { showSettings = true }
                }
            }
        } else {
            List {
                if let banner = store.banner {
                    Section {
                        Label(banner, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    ForEach(filtered) { bot in
                        NavigationLink(value: bot.engineId) {
                            BotRow(bot: bot, busy: store.busy.contains(bot.engineId), practice: store.mode(for: bot.engineId))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) { swipe(bot) }
                        .contextMenu { menu(bot) }
                    }
                } footer: {
                    Text("Pull to refresh. Status comes from each bot's check-in.")
                }
            }
            .searchable(text: $searchText, prompt: "Search bots")
            .navigationDestination(for: String.self) { EngineDetailView(engineId: $0) }
            .confirmationDialog(
                "Delete “\(BotNaming.display(pendingDelete?.engineId ?? ""))”?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete bot", role: .destructive) {
                    if let b = pendingDelete {
                        Task { await store.delete(b.engineId); Analytics.shared.track(.botDeleted) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This stops the bot and removes it. Your saved broker login is kept on the server.")
            }
        }
    }

    @ViewBuilder
    private func swipe(_ bot: EngineInfo) -> some View {
        if appState.hasAPIKey {
            Button(role: .destructive) { pendingDelete = bot } label: { Label("Delete", systemImage: "trash") }
            if bot.runState == .running || bot.runState == .stale {
                Button { Task { await store.perform(.stop, on: bot.engineId) } } label: {
                    Label("Stop", systemImage: "stop.fill")
                }.tint(.orange)
            } else {
                Button { Task { await store.perform(.start, on: bot.engineId); Analytics.shared.track(.botStarted(live: false)) } } label: {
                    Label("Start", systemImage: "play.fill")
                }.tint(Theme.profitGreen)
            }
        }
    }

    @ViewBuilder
    private func menu(_ bot: EngineInfo) -> some View {
        if appState.hasAPIKey {
            Button { Task { await store.perform(.start, on: bot.engineId) } } label: { Label("Start", systemImage: "play.fill") }
            Button { Task { await store.perform(.stop, on: bot.engineId) } } label: { Label("Stop", systemImage: "stop.fill") }
            Button { Task { await store.perform(.restart, on: bot.engineId) } } label: { Label("Restart", systemImage: "arrow.clockwise") }
            Divider()
            Button(role: .destructive) { pendingDelete = bot } label: { Label("Delete", systemImage: "trash") }
        } else {
            Label("Add your admin code in Settings to control bots", systemImage: "key")
        }
    }
}

struct BotRow: View {
    let bot: EngineInfo
    let busy: Bool
    /// Real Practice/Live mode for running bots (nil = unknown/stopped).
    var practice: Bool?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: strategyIcon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(BotNaming.display(bot.engineId)).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if busy { ProgressView() } else { StatusChip(status: AppStatus(runState: bot.runState), compact: true) }
                if let practice, bot.runState == .running {
                    Text(practice ? "Practice" : "Live")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(practice ? .orange : Theme.lossRed)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var strategyIcon: String {
        EngineStrategy(rawValue: bot.strategy ?? "")?.iconName ?? "cpu"
    }
    private var subtitle: String {
        var parts: [String] = [EngineStrategy.friendlyName(forRaw: bot.strategy)]
        if let b = bot.broker, !b.isEmpty { parts.append(b.capitalized) }
        return parts.joined(separator: " · ")
    }
}
