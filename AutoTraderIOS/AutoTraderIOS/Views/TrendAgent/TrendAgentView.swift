import SwiftUI

struct TrendAgentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TrendAgentVM()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    StatusCard(vm: vm, client: appState.client)

                    NavigationLink {
                        TrendLaunchForm(vm: vm).environmentObject(appState)
                    } label: {
                        ConfigRow(
                            title: "Launch Configuration",
                            subtitle: "\(vm.selectedSymbols.joined(separator: ", ")) · \(vm.adaptive ? "Adaptive" : "Static")",
                            icon: "slider.horizontal.3",
                            color: .teal
                        )
                    }
                    .buttonStyle(.plain)

                    if let positions = vm.signals?.openPositions, !positions.isEmpty {
                        sectionHeader("Open Positions")
                        ForEach(positions) { TrendPositionCard(position: $0) }
                    }

                    if let learning = vm.learning {
                        sectionHeader("Adaptive Learning")
                        LearningSummaryCard(learning: learning)
                        NavigationLink {
                            TrendAdaptiveProgressView(learning: learning)
                        } label: {
                            ConfigRow(
                                title: "Adaptive Progress",
                                subtitle: "Cycle \(learning.adaptiveParams?.cycleCount ?? 0) · \(learning.learningHistory?.count ?? 0) learning cycles · win rate trend",
                                icon: "chart.xyaxis.line",
                                color: .indigo
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        TrendTradesView(vm: vm).environmentObject(appState)
                    } label: {
                        ConfigRow(
                            title: "Trade History & Logs",
                            subtitle: "Recent trend-agent activity",
                            icon: "list.bullet.rectangle",
                            color: .gray
                        )
                    }
                    .buttonStyle(.plain)

                    if let err = vm.error {
                        Label(err, systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Trend Agent")
            .refreshable { await vm.refresh(client: appState.client) }
            .onAppear { vm.startPolling(client: appState.client) }
            .onDisappear { vm.stopPolling() }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Status Card

private struct StatusCard: View {
    @ObservedObject var vm: TrendAgentVM
    let client: APIClient

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(vm.isRunning ? .green : .secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.isRunning ? "Agent Running" : "Agent Stopped")
                        .font(.headline)
                    Text(vm.status?.engine ?? "Multi-timeframe option buyer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let open = vm.status?.openPositions, open > 0 {
                    VStack(spacing: 1) {
                        Text("\(open)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.green)
                        Text("open")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 10) {
                if vm.isRunning {
                    Button {
                        vm.stop(client: client)
                    } label: {
                        actionLabel(vm.isStopping ? "Stopping…" : "Stop Agent", loading: vm.isStopping)
                            .foregroundStyle(.white)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isStopping)
                } else {
                    Button {
                        vm.launch(client: client)
                    } label: {
                        actionLabel(vm.isLaunching ? "Launching…" : (vm.dryRun ? "Launch (Dry Run)" : "Launch LIVE"),
                                    loading: vm.isLaunching)
                            .foregroundStyle(.white)
                            .background(vm.dryRun ? Color.blue : Color.red,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLaunching)
                }
            }
            .padding(16)

            if let success = vm.launchSuccess {
                Label(success, systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            }
            if let err = vm.launchError {
                Label(err, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .glassCard()
        .confirmationDialog(
            "LIVE Mode — real option orders will be placed",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Launch LIVE Agent", role: .destructive) {
                vm.confirmLiveLaunch(client: client)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func actionLabel(_ text: String, loading: Bool) -> some View {
        HStack(spacing: 6) {
            if loading {
                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8)
            }
            Text(text).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }
}

// MARK: - Position Card

private struct TrendPositionCard: View {
    let position: TrendPosition

    private var pnl: Double { position.livePnl }
    private var pnlColor: Color { pnl >= 0 ? .green : .red }
    private var isCE: Bool { (position.optionType ?? "").uppercased() == "CE" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(position.tradingsymbol ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(position.optionType ?? "—")
                            .font(.caption2.bold())
                            .foregroundStyle(isCE ? .green : .red)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill((isCE ? Color.green : Color.red).opacity(0.15)))
                        if let conf = position.confidence {
                            Text("conf \(Int(conf * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let sign = pnl >= 0 ? "+" : ""
                    Text(sign + "₹" + String(format: "%.0f", abs(pnl)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(pnlColor)
                    Text(position.status?.uppercased() ?? "")
                        .font(.caption2.bold())
                        .foregroundStyle(position.isOpen ? .green : .secondary)
                }
            }
            .padding(14)

            Divider().padding(.horizontal, 14)

            HStack(spacing: 14) {
                miniMetric("Entry", String(format: "%.1f", position.entryPrice ?? 0))
                miniMetric("LTP", String(format: "%.1f", position.currentPrice ?? 0))
                miniMetric("SL", String(format: "%.1f", position.stopLoss ?? 0), color: .red)
                miniMetric("T1/T2",
                           "\(Int(position.target1 ?? 0))/\(Int(position.target2 ?? 0))",
                           color: .green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .thinGlassCard()
    }

    private func miniMetric(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Learning Summary

private struct LearningSummaryCard: View {
    let learning: TrendLearning

    var body: some View {
        let summary = learning.tradeSummary
        let params = learning.adaptiveParams
        HStack(spacing: 0) {
            statTile("Win Rate",
                     value: Format.percent(summary?.winRate),
                     color: .green)
            Divider().frame(height: 40)
            statTile("Closed",
                     value: summary?.totalClosed.map(String.init) ?? "0",
                     color: .primary)
            Divider().frame(height: 40)
            statTile("Total P&L",
                     value: Format.inr(summary?.totalPnl),
                     color: (summary?.totalPnl ?? 0) >= 0 ? .green : .red)
            Divider().frame(height: 40)
            statTile("Cycle",
                     value: params?.cycleCount.map(String.init) ?? "0",
                     color: .indigo)
        }
        .padding(.vertical, 14)
        .glassCard()
    }

    private func statTile(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Config Row

private struct ConfigRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .thinGlassCard()
    }
}
