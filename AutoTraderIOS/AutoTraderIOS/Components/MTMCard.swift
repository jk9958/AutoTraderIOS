import SwiftUI

struct MTMCard: View {
    let mtm: MTMData

    private var pnlColor: Color {
        let inr = mtm.mtmInr ?? 0
        return inr >= 0 ? Theme.green : Theme.red
    }

    private var pnlSign: String {
        let inr = mtm.mtmInr ?? 0
        return inr >= 0 ? "+" : ""
    }

    private var statusColor: Color {
        switch mtm.status?.lowercased() {
        case "open":
            return Theme.green
        case "closed":
            return Theme.textSecondary
        default:
            return Theme.orange
        }
    }

    private var pnlPercentage: String {
        let pts = Double(mtm.mtmPts ?? 0)
        let credit = Double(mtm.netCredit ?? 1)
        let pct = (pts / credit) * 100
        return String(format: "%.1f", pct)
    }

    private var formattedTimestamp: String {
        guard let ts = mtm.timestamp else { return "" }
        return ts.replacingOccurrences(of: "T", with: " ").prefix(16).description
    }

    var body: some View {
        VStack(spacing: 0) {
            mtmHeader
            Divider()
                .background(Color.white.opacity(0.08))
            mtmDetailsGrid
            Divider()
                .background(Color.white.opacity(0.08))
            mtmStrikes
        }
        .background(Theme.cardBg)
        .cornerRadius(Theme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            pnlColor.opacity(0.3),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var mtmHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MARK-TO-MARKET P&L")
                .font(.caption.bold())
                .foregroundColor(Theme.textSecondary)
                .tracking(0.5)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let inr = mtm.mtmInr {
                        pnlRupees(inr)
                    }
                    if let pts = mtm.mtmPts {
                        pnlPoints(pts)
                    }
                }
                Spacer()
                if let status = mtm.status {
                    StatusPill(label: status.uppercased(), color: statusColor)
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
                Theme.glassBg
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
    }

    @ViewBuilder
    private func pnlRupees(_ inr: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: inr >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(pnlColor)
            Text("\(pnlSign)₹\(abs(inr).formatted())")
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundColor(pnlColor)
        }
    }

    @ViewBuilder
    private func pnlPoints(_ pts: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(pnlSign)\(abs(pts))")
                .font(.headline.monospacedDigit())
                .foregroundColor(pnlColor)
            Text("pts (\(pnlPercentage)%)")
                .font(.caption.bold())
                .foregroundColor(pnlColor.opacity(0.8))
        }
    }

    @ViewBuilder
    private var mtmDetailsGrid: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                spotRow
                Divider()
                    .background(Color.white.opacity(0.05))
                creditRow
                Divider()
                    .background(Color.white.opacity(0.05))
                targetRow
                Divider()
                    .background(Color.white.opacity(0.05))
                lotsRow
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var spotRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spot")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let spot = mtm.spot {
                    Text(String(format: "%.0f", spot))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Entry Spot")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let entry = mtm.entrySpot {
                    Text(String(format: "%.0f", entry))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var creditRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Credit")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let credit = mtm.netCredit {
                    Text("\(credit) pts")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.green)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Cost to Close")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let cost = mtm.costToClose {
                    Text("\(cost) pts")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var targetRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Target")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let target = mtm.profitTargetPts {
                    Text("≤ \(target) pts")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.green)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Stop Loss")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let sl = mtm.slPts {
                    Text("≥ \(sl) pts")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.red)
                }
            }
        }
    }

    @ViewBuilder
    private var lotsRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lots")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                if let lots = mtm.lots, let size = mtm.lotSize {
                    Text("\(lots) × \(size)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Updated")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(formattedTimestamp)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var mtmStrikes: some View {
        if let shortCe = mtm.shortCe, let longCe = mtm.longCe, let shortPe = mtm.shortPe, let longPe = mtm.longPe {
            HStack(spacing: 8) {
                Text("CE \(shortCe) / \(longCe)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(Theme.textSecondary)
                Divider()
                    .frame(height: 12)
                Text("PE \(shortPe) / \(longPe)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.02))
        }
    }
}

#Preview {
    MTMCard(mtm: MTMData(
        mtmInr: 2500,
        mtmPts: 50,
        status: "open",
        spot: 23400,
        entrySpot: 23350,
        netCredit: 200,
        costToClose: 150,
        profitTargetPts: 100,
        slPts: 500,
        lots: 1,
        lotSize: 50,
        shortCe: "23500",
        longCe: "23800",
        shortPe: "23000",
        longPe: "22700",
        timestamp: "2026-05-26T14:30:00"
    ))
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
