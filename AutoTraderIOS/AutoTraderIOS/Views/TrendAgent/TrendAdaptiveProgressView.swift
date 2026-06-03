import SwiftUI
import Charts

struct TrendAdaptiveProgressView: View {
    let learning: TrendLearning

    // Learning history arrives newest-first (SQLite ORDER BY cycle DESC).
    // Sort ascending for a left-to-right time progression.
    private var cycles: [LearningCycle] {
        (learning.learningHistory ?? []).sorted { ($0.cycle ?? 0) < ($1.cycle ?? 0) }
    }

    // Running cumulative P&L per cycle.
    private var cumulative: [(cycle: Int, total: Double)] {
        var sum = 0.0
        return cycles.map { c in
            sum += c.totalPnl ?? 0
            return (c.cycle ?? 0, sum)
        }
    }

    private var hasData: Bool { !cycles.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryGrid
                if hasData {
                    winRateChart
                    pnlChart
                    cycleDetail
                } else {
                    emptyState
                }
                NavigationLink {
                    TrendLearningView(learning: learning)
                } label: {
                    HStack {
                        Label("Evolved Parameters", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .thinGlassCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Adaptive Progress")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        let s = learning.tradeSummary
        let p = learning.adaptiveParams
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Win Rate",
                     value: s?.winRate.map { "\(Int($0 * 100))%" } ?? "—",
                     icon: "target", color: .green)
            StatTile(title: "Total P&L",
                     value: s?.totalPnl.map { signedRupee($0) } ?? "—",
                     icon: "indianrupeesign.circle", color: (s?.totalPnl ?? 0) >= 0 ? .green : .red)
            StatTile(title: "Closed Trades",
                     value: s?.totalClosed.map(String.init) ?? "0",
                     icon: "checkmark.seal", color: .blue)
            StatTile(title: "Learning Cycle",
                     value: p?.cycleCount.map(String.init) ?? "0",
                     icon: "brain.head.profile", color: .indigo)
        }
    }

    // MARK: - Win Rate Chart

    private var winRateChart: some View {
        ChartCard(title: "Win Rate by Cycle", subtitle: "Target: above 50%") {
            Chart {
                RuleMark(y: .value("Breakeven", 0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.5))

                ForEach(cycles) { c in
                    if let wr = c.winRate {
                        LineMark(
                            x: .value("Cycle", c.cycle ?? 0),
                            y: .value("Win Rate", wr)
                        )
                        .foregroundStyle(Color.green)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Cycle", c.cycle ?? 0),
                            y: .value("Win Rate", wr)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.green.opacity(0.25), .green.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Cycle", c.cycle ?? 0),
                            y: .value("Win Rate", wr)
                        )
                        .foregroundStyle(Color.green)
                    }
                }
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text("\(Int(d * 100))%")
                        }
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(cycles.count, 6))) }
            .frame(height: 180)
        }
    }

    // MARK: - P&L Chart

    private var pnlChart: some View {
        ChartCard(title: "Cumulative P&L", subtitle: "Running total across cycles") {
            Chart {
                ForEach(cumulative, id: \.cycle) { item in
                    LineMark(
                        x: .value("Cycle", item.cycle),
                        y: .value("P&L", item.total)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.monotone)

                    AreaMark(
                        x: .value("Cycle", item.cycle),
                        y: .value("P&L", item.total)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue.opacity(0.25), .blue.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(compactRupee(d))
                        }
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(cycles.count, 6))) }
            .frame(height: 180)
        }
    }

    // MARK: - Per-cycle detail

    private var cycleDetail: some View {
        ChartCard(title: "P&L per Cycle", subtitle: nil) {
            Chart {
                ForEach(cycles) { c in
                    BarMark(
                        x: .value("Cycle", c.cycle ?? 0),
                        y: .value("P&L", c.totalPnl ?? 0)
                    )
                    .foregroundStyle((c.totalPnl ?? 0) >= 0 ? Color.green : Color.red)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) { Text(compactRupee(d)) }
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(cycles.count, 6))) }
            .frame(height: 150)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.secondary)
            Text("No Learning Cycles Yet")
                .font(.headline)
            Text("The agent evolves its parameters after every 20 closed trades. Progress will chart here once the first learning cycle completes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .glassCard()
    }

    // MARK: - Helpers

    private func signedRupee(_ v: Double) -> String {
        (v >= 0 ? "+₹" : "-₹") + String(format: "%.0f", abs(v))
    }

    private func compactRupee(_ v: Double) -> String {
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        if a >= 100_000 { return "\(sign)₹\(String(format: "%.1f", a / 100_000))L" }
        if a >= 1_000   { return "\(sign)₹\(String(format: "%.0f", a / 1_000))k" }
        return "\(sign)₹\(Int(a))"
    }
}

// MARK: - Reusable Chart Card

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
                .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
    }
}
