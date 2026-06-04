import SwiftUI

struct MTMCard: View {
    let mtm: MTMData

    private var inr: Double { mtm.mtmInr ?? 0 }
    private var pts: Double { mtm.mtmPts ?? 0 }
    private var isProfit: Bool { inr >= 0 }
    private var isOpen: Bool { mtm.status?.lowercased() == "open" }
    private var pnlColor: Color { isProfit ? .green : .red }
    private var sign: String { inr >= 0 ? "+" : "" }
    private var creditPct: Double {
        let credit = mtm.netCredit ?? 1
        guard credit > 0 else { return 0 }
        return (pts / credit) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 16)
            metricsGrid
            if mtm.shortCe != nil || mtm.shortPe != nil {
                Divider().padding(.horizontal, 16)
                strikesRow
            }
        }
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [pnlColor.opacity(0.35), pnlColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Position")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                pnlRupees
                pnlPoints
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                statusPill
                if let ts = mtm.timestamp {
                    Text(shortTime(ts))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
    }

    private var pnlRupees: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(sign + "₹")
                .font(.title2.weight(.semibold))
                .foregroundStyle(pnlColor)
            Text(String(format: "%.2f", abs(inr)))
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(pnlColor)
        }
    }

    private var pnlPoints: some View {
        HStack(spacing: 4) {
            Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
            Text(String(format: "%@%.2f pts · %.1f%%", sign, abs(pts), abs(creditPct)))
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(pnlColor.opacity(0.85))
    }

    private var statusPill: some View {
        Text(mtm.status?.uppercased() ?? "—")
            .font(.caption.bold())
            .foregroundStyle(isOpen ? .green : .secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Capsule().fill((isOpen ? Color.green : Color.secondary).opacity(0.15)))
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MTMMetric("Spot", value: formatted(mtm.spot), unit: nil)
            MTMMetric("Entry", value: formatted(mtm.entrySpot), unit: nil)
            MTMMetric("Net Credit", value: formatted2(mtm.netCredit), unit: "pts", valueColor: .green)
            MTMMetric("Cost to Close", value: formatted2(mtm.costToClose), unit: "pts", valueColor: .orange)
            MTMMetric("Target", value: "≤" + formatted2(mtm.profitTargetPts), unit: "pts", valueColor: .blue)
            MTMMetric("Stop Loss", value: "≥" + formatted2(mtm.slPts), unit: "pts", valueColor: .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Strikes

    private var strikesRow: some View {
        HStack(spacing: 16) {
            if let sce = mtm.shortCe, let lce = mtm.longCe {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CE").font(.caption2).foregroundStyle(.secondary)
                    Text("\(Format.intString(sce)) / \(Format.intString(lce))").font(.caption.monospacedDigit()).foregroundStyle(.red)
                }
            }
            if let spe = mtm.shortPe, let lpe = mtm.longPe {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PE").font(.caption2).foregroundStyle(.secondary)
                    Text("\(Format.intString(spe)) / \(Format.intString(lpe))").font(.caption.monospacedDigit()).foregroundStyle(.green)
                }
            }
            Spacer()
            if let lots = mtm.lots, let size = mtm.lotSize {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lots").font(.caption2).foregroundStyle(.secondary)
                    Text("\(lots) × \(size)").font(.caption.monospacedDigit())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func formatted(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f", v)
    }
    private func formatted2(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.2f", v)
    }
    private func shortTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df.string(from: date)
    }
}

// MARK: - Metric Cell

private struct MTMMetric: View {
    let label: String
    let value: String
    let unit: String?
    var valueColor: Color = .primary

    init(_ label: String, value: String, unit: String?, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.unit = unit
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
