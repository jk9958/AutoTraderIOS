import SwiftUI
import Charts

struct PnLView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PnLVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.daily.isEmpty {
                    ProgressView("Loading P&L…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.daily.isEmpty {
                    ContentUnavailableView(
                        "No trades yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(vm.error ?? "Closed trades will appear here as a P&L chart.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summary
                            chartCard
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("P&L")
            .refreshable { await vm.load(appState: appState) }
            .task { await vm.load(appState: appState) }
        }
    }

    private var summary: some View {
        HStack {
            stat("Trades", "\(vm.totalTrades)")
            Divider().frame(height: 36)
            stat("Win rate", String(format: "%.0f%%", vm.winRate * 100))
            Divider().frame(height: 36)
            stat("Total P&L", String(format: "₹%@%.0f", vm.totalPnL >= 0 ? "+" : "", vm.totalPnL),
                 color: vm.totalPnL >= 0 ? Theme.green : Theme.red)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassStyle()
    }

    private func stat(_ label: String, _ value: String, color: Color = Theme.textPrimary) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(color).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily P&L").font(.subheadline).foregroundStyle(.secondary)
            Chart(vm.daily) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("P&L", item.pnl)
                )
                .foregroundStyle(item.pnl >= 0 ? Theme.green : Theme.red)

                LineMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Cumulative", item.cumulative)
                )
                .foregroundStyle(Theme.blue)
                .interpolationMethod(.catmullRom)
                .symbol(Circle())
            }
            .frame(height: 240)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .padding()
        .glassStyle()
    }
}
