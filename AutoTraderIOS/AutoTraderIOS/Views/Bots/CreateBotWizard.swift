import SwiftUI

/// Guided, 4-step "create a bot" flow for novices. Defaults to Practice mode and
/// requires an explicit confirm to go Live. Maps a friendly name → engine_id.
struct CreateBotWizard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateEngineVM()

    var onCreated: () -> Void

    @State private var step = 0
    @State private var botName = ""
    @State private var startNow = false
    @State private var confirmLive = false

    private let lastStep = 3
    private var slug: String { EngineValidation.slugify(botName) }
    private var nameValid: Bool { EngineValidation.isValidEngineId(slug) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(lastStep + 1))
                    .tint(.blue)
                    .padding(.horizontal)

                TabView(selection: $step) {
                    styleStep.tag(0)
                    brokerStep.tag(1)
                    nameStep.tag(2)
                    reviewStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.default, value: step)

                footer
            }
            .navigationTitle("New bot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onChange(of: vm.broker) { _, _ in vm.engineId = slug }
    }

    // MARK: Steps

    private var styleStep: some View {
        stepScaffold(title: "Pick a trading style",
                     help: "This is the strategy the bot follows. You can create more bots later.") {
            VStack(spacing: 12) {
                ForEach(EngineStrategy.allCases) { s in
                    Button {
                        Haptics.tap(); vm.strategy = s
                        withAnimation { step = 1 }   // auto-advance
                    } label: {
                        styleCard(s, selected: vm.strategy == s)
                    }.buttonStyle(.plain)
                }
                Text("Not sure? **Range Income** is the gentlest place to start.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func styleCard(_ s: EngineStrategy, selected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: s.iconName)
                .font(.title2).foregroundStyle(selected ? .white : .blue)
                .frame(width: 44, height: 44)
                .background(selected ? Color.blue : Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(s.friendlyName).font(.headline)
                    if s == .ironCondor {
                        Text("Recommended")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.profitGreen.opacity(0.18), in: Capsule())
                            .foregroundStyle(Theme.profitGreen)
                    }
                }
                Text(s.subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(s.risk.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(s.risk == .lower ? Theme.profitGreen : .orange)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? .blue : .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(selected ? Color.blue : .clear, lineWidth: 2)
        )
    }

    private var brokerStep: some View {
        stepScaffold(title: "Choose a broker",
                     help: "The account that places the trades. Practice mode works even if a broker isn't connected yet.") {
            VStack(spacing: 12) {
                ForEach(EngineBroker.allCases) { b in
                    let connected = brokerConnected(b.rawValue)
                    Button {
                        Haptics.tap(); vm.broker = b
                        withAnimation { step = 2 }   // auto-advance
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(b.displayName).font(.headline).foregroundStyle(.primary)
                                Text(connected ? "Connected" : "Not connected — Practice only")
                                    .font(.caption)
                                    .foregroundStyle(connected ? Theme.profitGreen : .secondary)
                            }
                            Spacer()
                            Image(systemName: vm.broker == b ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(vm.broker == b ? .blue : .secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .glassCard()
                    }.buttonStyle(.plain)
                }
                Text("You can connect a broker later from More → Brokers.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func brokerConnected(_ id: String) -> Bool {
        let v = appState.serverStatus?.tokens?[id] ?? ""
        return v.contains("updated") || v.contains("loaded") || v.contains("active")
    }

    private var nameStep: some View {
        stepScaffold(title: "Name your bot",
                     help: "Just for you — pick something memorable.") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("My Range Bot", text: $botName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: botName) { _, _ in vm.engineId = slug }
                if !botName.isEmpty {
                    if nameValid {
                        Label("Saved as “\(slug)”", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Please include some letters or numbers.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        stepScaffold(title: "Review & create",
                     help: "Bots start in Practice mode so you can watch them safely.") {
            VStack(spacing: 14) {
                summaryRow("Name", BotNaming.display(slug))
                summaryRow("Style", vm.strategy.friendlyName)
                summaryRow("Broker", vm.broker.displayName)
                Divider()
                Toggle(isOn: Binding(get: { vm.dryRun }, set: { newVal in
                    vm.dryRun = newVal
                    if !newVal { confirmLive = true }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.dryRun ? "Practice mode" : "Live mode")
                            .font(.subheadline.weight(.semibold))
                        Text(vm.dryRun ? "No real money — fully simulated."
                                       : "⚠️ Real trades with real money.")
                            .font(.caption)
                            .foregroundStyle(vm.dryRun ? .secondary : Theme.lossRed)
                    }
                }
                Toggle("Start right away", isOn: $startNow)
                if vm.banner != nil {
                    Label(vm.banner!, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(16)
            .glassCard()
        }
        .alert("Use real money?", isPresented: $confirmLive) {
            Button("Keep Practice", role: .cancel) { vm.dryRun = true }
            Button("Use Live money", role: .destructive) { vm.dryRun = false }
        } message: {
            Text("Live mode places real trades with real funds. You can change this later in the bot's settings.")
        }
    }

    private func summaryRow(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).fontWeight(.medium) }
            .font(.subheadline)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.bordered)
            }
            if step < lastStep {
                Button("Continue") { withAnimation { step += 1 } }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(step == 2 && !nameValid)
            } else {
                Button {
                    vm.autostart = startNow
                    vm.engineId = slug
                    Task {
                        if await vm.submit(client: appState.client) {
                            Analytics.shared.track(.botCreated(strategy: vm.strategy.rawValue, live: !vm.dryRun))
                            if startNow { Analytics.shared.track(.botStarted(live: !vm.dryRun)) }
                            onCreated()
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if vm.isSubmitting { ProgressView().controlSize(.small) }
                        Text("Create bot")
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!nameValid || vm.isSubmitting)
            }
        }
        .controlSize(.large)
        .padding()
    }

    @ViewBuilder
    private func stepScaffold<Content: View>(title: String, help: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.title2.bold())
                Text(help).font(.subheadline).foregroundStyle(.secondary)
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
