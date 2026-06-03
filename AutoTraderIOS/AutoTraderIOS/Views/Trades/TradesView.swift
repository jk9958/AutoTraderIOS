import SwiftUI

struct TradesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradesVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.trades.isEmpty && vm.mtm == nil {
                    loadingView
                } else if vm.trades.isEmpty && vm.mtm == nil {
                    emptyView
                } else {
                    content
                }
            }
            .navigationTitle("Positions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.fetch(client: appState.client) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { Task { await vm.fetch(client: appState.client) } }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if let mtm = vm.mtm {
                    MTMCard(mtm: mtm)
                }

                if !vm.trades.isEmpty {
                    sectionHeader("History")
                    ForEach(Array(vm.trades.enumerated()), id: \.offset) { _, trade in
                        TradeCard(trade: trade)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await vm.fetch(client: appState.client) }
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

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading positions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            Text("No Positions")
                .font(.title3.weight(.semibold))
            Text("Trades will appear here after an engine launch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Trade Card

private struct TradeCard: View {
    let trade: [String: String]

    private var isDryRun: Bool     { trade["dry_run"]?.lowercased() == "true" }
    private var entryDate: String  { trade["entry_date"] ?? trade["date"] ?? "—" }
    private var instrument: String { trade["instrument"] ?? "" }
    private var exitReason: String { trade["exit_reason"] ?? "" }
    private var entryTime: String  { shortTime(trade["entry_time"]) }
    private var exitTime: String   { shortTime(trade["exit_time"]) }

    private var pnlPts: Double? {
        guard let pnl = trade["pnl_pts"] ?? trade["pnl_points"], !pnl.isEmpty else { return nil }
        return Double(pnl)
    }
    private var pnlInr: Double? {
        guard let pnl = trade["pnl_rupees"] ?? trade["pnl_inr"], !pnl.isEmpty else { return nil }
        return Double(pnl)
    }

    private var isProfit: Bool { (pnlPts ?? 0) >= 0 }
    private var pnlColor: Color { isProfit ? .green : .red }
    private var exitReasonColor: Color {
        switch exitReason {
        case "PROFIT_TARGET": return .green
        case "SL", "HARD_STOP": return .red
        case "EOD": return .secondary
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: P&L
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if let inr = pnlInr {
                        let sign = inr >= 0 ? "+" : ""
                        Text(sign + "₹" + String(format: "%.0f", abs(inr)))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(pnlColor)
                    }
                    if let pts = pnlPts {
                        let sign = pts >= 0 ? "+" : ""
                        Text(sign + String(format: "%.2f pts", abs(pts)))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(pnlColor.opacity(0.8))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if !exitReason.isEmpty {
                        Text(exitReason)
                            .font(.caption.bold())
                            .foregroundStyle(exitReasonColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(exitReasonColor.opacity(0.14)))
                    }
                    Label(isDryRun ? "Dry Run" : "Live", systemImage: isDryRun ? "play.circle" : "record.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isDryRun ? Color.secondary : Color.green)
                }
            }
            .padding(14)

            Divider().padding(.horizontal, 14)

            // Bottom row: date + time
            HStack(spacing: 16) {
                if !instrument.isEmpty {
                    Label(instrument.uppercased(), systemImage: "chart.bar.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(entryDate)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if !entryTime.isEmpty || !exitTime.isEmpty {
                    Text([entryTime, exitTime].filter { !$0.isEmpty }.joined(separator: " → "))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .thinGlassCard()
    }

    private func shortTime(_ raw: String?) -> String {
        guard let raw, raw.contains("T") else { return raw ?? "" }
        return String(raw.split(separator: "T").last?.prefix(5) ?? "")
    }
}
