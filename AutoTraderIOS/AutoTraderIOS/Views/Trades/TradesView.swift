import SwiftUI

struct TradesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradesVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.trades.isEmpty && vm.mtm == nil {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading positions…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if vm.trades.isEmpty && vm.mtm == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("No Positions")
                            .font(.headline)
                        Text("Trades will appear here after launch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        if let mtm = vm.mtm {
                            Section {
                                mtmRows(mtm)
                            } header: {
                                Text("Live Position")
                            }
                        }

                        if !vm.trades.isEmpty {
                            Section {
                                ForEach(Array(vm.trades.enumerated()), id: \.offset) { _, trade in
                                    TradeRow(trade: trade)
                                }
                            } header: {
                                Text("History")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await vm.fetch(client: appState.client) }
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

    @ViewBuilder
    private func mtmRows(_ mtm: MTMData) -> some View {
        let inr = mtm.mtmInr ?? 0
        let pnlColor: Color = inr >= 0 ? .green : .red
        let sign = inr >= 0 ? "+" : ""
        let isOpen = mtm.status?.lowercased() == "open"

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(sign)₹\(String(format: "%.2f", abs(inr)))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(pnlColor)
                if let pts = mtm.mtmPts {
                    let credit = mtm.netCredit ?? 1
                    let pct = credit > 0 ? (pts / credit) * 100 : 0
                    Text("\(sign)\(String(format: "%.2f", abs(pts))) pts · \(String(format: "%.1f", abs(pct)))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(pnlColor.opacity(0.8))
                }
            }
            Spacer()
            if let status = mtm.status {
                Text(status.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(isOpen ? Color.green : Color.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((isOpen ? Color.green : Color.secondary).opacity(0.15))
                    .clipShape(Capsule())
            }
        }

        LabeledContent("Spot / Entry") {
            Text("\(String(format: "%.0f", mtm.spot ?? 0)) / \(String(format: "%.0f", mtm.entrySpot ?? 0))")
                .monospacedDigit()
        }
        LabeledContent("Net Credit") {
            Text("\(String(format: "%.2f", mtm.netCredit ?? 0)) pts")
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        LabeledContent("Cost to Close") {
            Text("\(String(format: "%.2f", mtm.costToClose ?? 0)) pts")
                .foregroundStyle(.orange)
                .monospacedDigit()
        }
        LabeledContent("Target / SL") {
            Text("≤\(String(format: "%.2f", mtm.profitTargetPts ?? 0)) / ≥\(String(format: "%.2f", mtm.slPts ?? 0))")
                .font(.footnote.monospacedDigit())
        }
        if let sce = mtm.shortCe, let lce = mtm.longCe, let spe = mtm.shortPe, let lpe = mtm.longPe {
            LabeledContent("Strikes") {
                Text("CE \(Int(sce))/\(Int(lce)) · PE \(Int(spe))/\(Int(lpe))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TradeRow: View {
    let trade: [String: String]

    private var isDryRun: Bool { trade["dry_run"]?.lowercased() == "true" }
    private var entryDate: String { trade["date"] ?? trade["entry_date"] ?? "—" }
    private var instrument: String { trade["instrument"] ?? "" }
    private var exitReason: String { trade["exit_reason"] ?? "" }
    private var pnlDouble: Double? {
        guard let pnl = trade["pnl_pts"] ?? trade["pnl_points"] ?? trade["pnl"], !pnl.isEmpty else { return nil }
        return Double(pnl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(isDryRun ? "Dry Run" : "Live", systemImage: isDryRun ? "play.circle" : "record.circle.fill")
                    .font(.caption)
                    .foregroundStyle(isDryRun ? Color.gray : Color.green)

                if !exitReason.isEmpty {
                    Text(exitReason)
                        .font(.caption.bold())
                        .foregroundStyle(exitReason == "OPEN" ? .blue : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((exitReason == "OPEN" ? Color.blue : Color.orange).opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                if let pnl = pnlDouble {
                    let isProfit = pnl >= 0
                    HStack(spacing: 2) {
                        Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.bold())
                        Text(String(format: "%.2f", abs(pnl)))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                    .foregroundStyle(isProfit ? .green : .red)
                }
            }

            HStack(spacing: 6) {
                if !instrument.isEmpty {
                    Text(instrument)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(entryDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
