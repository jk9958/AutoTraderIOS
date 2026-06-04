import SwiftUI

/// Novice-facing list of trading bots (multi-engine mobile API). Reads the shared
/// `EnginesStore` so it always agrees with Home. Each row shows a visible
/// Start/Stop control; the row body opens the bot's details.
struct BotsListView: View {
    @EnvironmentObject var appState: AppState

    @State private var showCreate = false
    @State private var showSettings = false
    @State private var showNeedsCode = false
    @State private var pendingDelete: EngineInfo?
    @State private var route: String?
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
                        Button { createTapped() } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Create a bot")
                    }
                }
                .sheet(isPresented: $showCreate) {
                    CreateBotWizard { store.toast = .success("Bot created"); Task { await store.refresh() } }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .alert("You'll need an access code", isPresented: $showNeedsCode) {
                    Button("Open Settings") { showSettings = true }
                    Button("Not now", role: .cancel) {}
                } message: {
                    Text("Creating bots needs an admin access code from whoever set up your server. Add it in Settings.")
                }
                .refreshable { await store.refresh() }
                .task { await store.refresh(showSpinner: true) }
                .onChange(of: store.banner) { _, msg in
                    if msg != nil { Task { try? await Task.sleep(for: .seconds(4)); store.banner = nil } }
                }
        }
        .toast(Binding(get: { store.toast }, set: { store.toast = $0 }))
    }

    private func createTapped() {
        if appState.hasAPIKey { showCreate = true } else { showNeedsCode = true }
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
                        row(bot)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) { swipe(bot) }
                            .contextMenu { menu(bot) }
                    }
                } footer: {
                    Text(appState.hasAPIKey
                         ? "Tap a bot for details. Use ▶/◼ to start or stop it."
                         : "Tap a bot for details. Add your access code in Settings to start or stop bots.")
                }
            }
            .searchable(text: $searchText, prompt: "Search bots")
            .navigationDestination(item: $route) { EngineDetailView(engineId: $0) }
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
    private func row(_ bot: EngineInfo) -> some View {
        HStack(spacing: 10) {
            Button { route = bot.engineId } label: {
                BotRow(bot: bot, busy: store.busy.contains(bot.engineId), practice: store.mode(for: bot.engineId))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if appState.hasAPIKey {
                rowControl(bot)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func rowControl(_ bot: EngineInfo) -> some View {
        let running = bot.runState == .running || bot.runState == .stale
        return Button {
            Task {
                await store.perform(running ? .stop : .start, on: bot.engineId)
                if !running { Analytics.shared.track(.botStarted(live: false)) }
            }
        } label: {
            Image(systemName: running ? "stop.fill" : "play.fill")
                .font(.title3)
                .foregroundStyle(running ? .orange : Theme.profitGreen)
                .frame(width: 40, height: 40)
                .background((running ? Color.orange : Theme.profitGreen).opacity(0.12), in: Circle())
        }
        .buttonStyle(.borderless)
        .disabled(store.busy.contains(bot.engineId))
        .accessibilityLabel(running ? "Stop \(BotNaming.display(bot.engineId))" : "Start \(BotNaming.display(bot.engineId))")
    }

    @ViewBuilder
    private func swipe(_ bot: EngineInfo) -> some View {
        if appState.hasAPIKey {
            Button(role: .destructive) { pendingDelete = bot } label: { Label("Delete", systemImage: "trash") }
            Button { Task { await store.perform(.restart, on: bot.engineId) } } label: {
                Label("Restart", systemImage: "arrow.clockwise")
            }.tint(.blue)
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
            Label("Add your access code in Settings to control bots", systemImage: "key")
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
