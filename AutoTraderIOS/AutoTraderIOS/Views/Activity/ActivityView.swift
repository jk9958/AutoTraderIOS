import SwiftUI

/// Activity tab — segmented into Open (live P&L), History (past trades), and
/// Stats (real results). Plain-language empty states everywhere.
struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ActivityVM()
    @State private var segment: Segment = .positions

    enum Segment: String, CaseIterable, Identifiable {
        case positions = "Open", trades = "History", performance = "Stats"
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
                        sectionLabel("Main trading engine")
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
        let stats = TradeStats(trades: vm.trades)
        if stats.total == 0 {
            empty(icon: "chart.bar",
                  title: "No results yet",
                  message: "Once your bots finish some trades, you'll see wins, losses, and total profit or loss here.")
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        statTile("Total P&L", stats.totalInrText, stats.totalInr >= 0 ? Theme.profitGreen : Theme.lossRed)
                        statTile("Trades", "\(stats.total)", .primary)
                    }
                    HStack(spacing: 12) {
                        statTile("Wins", "\(stats.wins)", Theme.profitGreen)
                        statTile("Losses", "\(stats.losses)", Theme.lossRed)
                    }
                    if let wr = stats.winRateText {
                        statTile("Win rate", wr, .blue).frame(maxWidth: .infinity)
                    }
                    infoCard("About these numbers",
                             "Based on completed trades the server has recorded. Practice trades are included.",
                             "info.circle")
                }
                .padding(16)
            }
        }
    }

    private func statTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(14)
        .glassCard()
    }

    // MARK: Building blocks

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            Spacer()
        }
    }

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

/// Summary stats computed client-side from the trade history (no server endpoint
/// exists for this). A trade counts toward stats only if it has a recorded P&L.
struct TradeStats {
    let total: Int
    let wins: Int
    let losses: Int
    let totalInr: Double

    init(trades: [[String: String]]) {
        var t = 0, w = 0, l = 0
        var sum = 0.0
        for trade in trades {
            guard let pnl = Double(trade["pnl_rupees"] ?? trade["pnl_inr"] ?? "") else { continue }
            t += 1
            sum += pnl
            if pnl >= 0 { w += 1 } else { l += 1 }
        }
        total = t; wins = w; losses = l; totalInr = sum
    }

    var totalInrText: String { Format.inr(totalInr) }
    var winRateText: String? {
        guard total > 0 else { return nil }
        return Format.percent(Double(wins) / Double(total))
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
                if let inr = pnlInr, inr.isFinite {
                    Text(Format.inr(inr))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isProfit ? Theme.profitGreen : Theme.lossRed)
                } else if let pts = pnlPts, pts.isFinite {
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
