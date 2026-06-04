import SwiftUI

struct TrendLearningView: View {
    let learning: TrendLearning

    var body: some View {
        List {
            if let p = learning.adaptiveParams {
                Section("Evolved Parameters") {
                    paramRow("Min Confidence", p.minConfidence.map { "\(Int($0 * 100))%" })
                    paramRow("Stop Loss", p.slPct.map { String(format: "%.0f%%", $0) })
                    paramRow("Target 1", p.target1Pct.map { String(format: "%.0f%%", $0) })
                    paramRow("Target 2", p.target2Pct.map { String(format: "%.0f%%", $0) })
                    paramRow("ADX Min", p.adxMin.map { String(format: "%.1f", $0) })
                    paramRow("IV Rank Max", p.ivRankMax.map { String(format: "%.0f", $0) })
                    paramRow("ATM Conf. Min", p.atmConfidenceMin.map { "\(Int($0 * 100))%" })
                    paramRow("OTM1 Conf. Min", p.otm1ConfidenceMin.map { "\(Int($0 * 100))%" })
                }

                if let weights = p.tfWeights, !weights.isEmpty {
                    Section("Timeframe Weights") {
                        ForEach(weights.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            LabeledContent(key) {
                                Text(String(format: "%.0f%%", value * 100)).monospacedDigit()
                            }
                        }
                    }
                }

                if let avoid = p.avoidConditions, !avoid.isEmpty {
                    Section("Avoided Conditions") {
                        ForEach(avoid, id: \.self) { Text($0).font(.subheadline) }
                    }
                }
            }

            if let history = learning.learningHistory, !history.isEmpty {
                Section("Learning Cycles") {
                    ForEach(history) { cycle in
                        LearningCycleRow(cycle: cycle)
                    }
                }
            }
        }
        .navigationTitle("Adaptive Learning")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func paramRow(_ label: String, _ value: String?) -> some View {
        LabeledContent(label) {
            Text(value ?? "—")
                .monospacedDigit()
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
}

private struct LearningCycleRow: View {
    let cycle: LearningCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cycle \(cycle.cycle ?? 0)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let pnl = cycle.totalPnl {
                    Text((pnl >= 0 ? "+₹" : "-₹") + String(format: "%.0f", abs(pnl)))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }
            HStack(spacing: 14) {
                metric("Trades", cycle.nTrades.map(String.init) ?? "—")
                metric("Win Rate", Format.percent(cycle.winRate))
                metric("Avg P&L", cycle.avgPnl.flatMap { $0.isFinite ? String(format: "₹%.0f", $0) : nil } ?? "—")
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit())
        }
    }
}
