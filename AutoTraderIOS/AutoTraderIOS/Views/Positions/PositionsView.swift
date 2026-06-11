import SwiftUI

struct PositionsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PositionsVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.mtm == nil && vm.isLoading {
                    ProgressView("Loading position…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !vm.hasPosition {
                    ContentUnavailableView(
                        "No open position",
                        systemImage: "chart.bar",
                        description: Text("Live mark-to-market appears here when an Iron Condor is running.")
                    )
                } else if let mtm = vm.mtm {
                    ScrollView {
                        VStack(spacing: 16) {
                            pnlHeader(mtm)
                            detailCard(mtm)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Positions")
            .refreshable { await vm.reload(appState: appState) }
            .task { vm.start(appState: appState) }
            .onDisappear { vm.stop() }
            .overlay(alignment: .bottom) {
                if let err = vm.error {
                    Text(err).font(.caption).foregroundStyle(.red).padding(.bottom, 8)
                }
            }
        }
    }

    private func pnlHeader(_ mtm: MTMData) -> some View {
        let inr = mtm.mtmInr ?? 0
        let pts = mtm.mtmPts ?? 0
        let color: Color = inr >= 0 ? Theme.green : Theme.red
        return VStack(spacing: 6) {
            Text("Mark-to-Market").font(.subheadline).foregroundStyle(.secondary)
            Text(String(format: "₹%@%.0f", inr >= 0 ? "+" : "", inr))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(String(format: "%@%.1f pts", pts >= 0 ? "+" : "", pts))
                .font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassStyle()
    }

    private func detailCard(_ mtm: MTMData) -> some View {
        VStack(spacing: 0) {
            row("Spot", value: fmt(mtm.spot))
            row("Entry spot", value: fmt(mtm.entrySpot))
            row("Short CE / PE", value: "\(fmt(mtm.shortCe)) / \(fmt(mtm.shortPe))")
            row("Long CE / PE", value: "\(fmt(mtm.longCe)) / \(fmt(mtm.longPe))")
            row("Net credit", value: fmt(mtm.netCredit))
            row("Cost to close", value: fmt(mtm.costToClose))
            row("Profit target", value: mtm.profitTargetPts.map { String(format: "%.0f pts", $0) } ?? "—")
            row("Stop loss", value: mtm.slPts.map { String(format: "%.0f pts", $0) } ?? "—")
            row("Lots", value: mtm.lots.map(String.init) ?? "—", divider: false)
        }
        .padding()
        .glassStyle()
    }

    private func row(_ label: String, value: String, divider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).fontWeight(.medium).monospacedDigit()
            }
            .padding(.vertical, 10)
            if divider { Divider().opacity(0.3) }
        }
        .font(.subheadline)
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f", v)
    }
}
