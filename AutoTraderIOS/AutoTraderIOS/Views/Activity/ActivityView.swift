import SwiftUI
import Charts

/// Activity tab — segmented into Positions (live P&L), Trades (history), and
/// Performance. Plain-language empty states everywhere.
struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ActivityVM()
    @State private var segment: Segment = .positions

    enum Segment: String, CaseIterable, Identifiable {
        case positions = "Positions", trades = "Trades", performance = "Performance"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    switch segment {
                    case .positions:   positions
                    case .trades:      tradeHistory
                    case .performance: performance
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.load(client: appState.client) }
            .refreshable { await vm.load(client: appState.client) }
        }
    }

    // MARK: Positions

    @ViewBuilder
    private var positions: some View {
        if vm.isLoading && vm.mtm == nil && !vm.scalpHasPositions {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading positions…").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    if let mtm = vm.mtm {
                        MTMCard(mtm: mtm)
                    } else if vm.scalpHasPositions {
                        infoCard("A Volatility Spike bot has open positions.",
                                 "Open its bot to see details.", "bolt.fill")
                    } else {
                        empty(icon: "tray",
                              title: "No open positions",
                              message: vm.marketOpen == false
                                ? "The market is closed right now. Positions appear here while a bot is in a trade."
                                : "When a bot enters a trade, its live profit or loss shows here.")
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: Trade history

    @ViewBuilder
    private var tradeHistory: some View {
        if vm.trades.isEmpty {
            empty(icon: "clock.arrow.circlepath",
                  title: "No trades yet",
                  message: "Completed trades will be listed here, newest first.")
        } else {
            List {
                ForEach(Array(vm.trades.enumerated()), id: \.offset) { _, t in
                    ActivityTradeRow(trade: t)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: Performance

    @ViewBuilder
    private var performance: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let buckets = vm.metrics?.per5min, !buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Server activity (last buckets)")
                            .font(.subheadline.weight(.semibold))
                        Chart(Array(buckets.enumerated()), id: \.offset) { idx, b in
                            BarMark(x: .value("Bucket", idx), y: .value("Lines", b.lines ?? 0))
                                .foregroundStyle(.blue)
                        }
                        .frame(height: 160)
                        .accessibilityLabel("Server activity over the last \(buckets.count) time buckets")
                        .accessibilityValue("\(vm.metrics?.totalLines ?? buckets.reduce(0) { $0 + ($1.lines ?? 0) }) log lines total")
                        if let total = vm.metrics?.totalLines {
                            Text("\(total) log lines total")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .glassCard()

                    infoCard("What is this?",
                             "A simple measure of how busy the server has been. Detailed trade performance appears as your bots close trades.",
                             "info.circle")
                } else {
                    empty(icon: "chart.bar",
                          title: "No performance data yet",
                          message: "Once your bots run and trade, summaries will appear here.")
                }
            }
            .padding(16)
        }
    }

    // MARK: Building blocks

    private func infoCard(_ title: String, _ message: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(.blue).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .thinGlassCard()
    }

    private func empty(icon: String, title: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: { Text(message) }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

/// One closed-trade row (history). Reads snake_case keys directly (dictionary
/// fields are not snake-case-converted by the shared decoder).
struct ActivityTradeRow: View {
    let trade: [String: String]

    private var pnlInr: Double? { Double(trade["pnl_rupees"] ?? trade["pnl_inr"] ?? "") }
    private var pnlPts: Double? { Double(trade["pnl_pts"] ?? trade["pnl_points"] ?? "") }
    private var isProfit: Bool { (pnlInr ?? pnlPts ?? 0) >= 0 }
    private var exitReason: String { trade["exit_reason"] ?? "" }
    private var date: String { trade["entry_date"] ?? trade["date"] ?? "" }
    private var isDryRun: Bool { (trade["dry_run"] ?? "").lowercased() == "true" }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                if let inr = pnlInr {
                    Text("\(inr >= 0 ? "+" : "-")₹\(Int(abs(inr)))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isProfit ? Theme.profitGreen : Theme.lossRed)
                } else if let pts = pnlPts {
                    Text("\(pts >= 0 ? "+" : "")\(String(format: "%.2f", pts)) pts")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isProfit ? Theme.profitGreen : Theme.lossRed)
                }
                HStack(spacing: 6) {
                    if !date.isEmpty { Text(date) }
                    if isDryRun { Text("· Practice") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !exitReason.isEmpty {
                Text(friendlyReason(exitReason))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func friendlyReason(_ raw: String) -> String {
        switch raw {
        case "PROFIT_TARGET": return "Hit target"
        case "SL", "HARD_STOP": return "Stopped out"
        case "EOD": return "Day end"
        default: return raw.capitalized
        }
    }
}
