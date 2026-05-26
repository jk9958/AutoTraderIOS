import SwiftUI

struct MTMCard: View {
    let mtm: MTMData

    private var pnlColor: Color {
        let inr = mtm.mtmInr ?? 0.0
        return inr >= 0 ? Theme.green : Theme.red
    }

    private var pnlSign: String {
        let inr = mtm.mtmInr ?? 0.0
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
        let pts = mtm.mtmPts ?? 0.0
        let credit = mtm.netCredit ?? 1.0
        let pct = (pts / credit) * 100
        return String(format: "%.1f", pct)
    }

    private var formattedTimestamp: String {
        guard let ts = mtm.timestamp else { return "" }
        return ts.replacingOccurrences(of: "T", with: " ").prefix(16).description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // P&L header with status
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    let inr = mtm.mtmInr ?? 0.0
                    Text("\(pnlSign)₹\(String(format: "%.2f", abs(inr)))")
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundColor(pnlColor)

                    if let pts = mtm.mtmPts {
                        HStack(spacing: 4) {
                            Text("\(pnlSign)\(String(format: "%.2f", abs(pts))) pts")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundColor(pnlColor)
                            Text("(\(pnlPercentage)%)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(pnlColor.opacity(0.8))
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
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

            // 2-column metrics grid (compact)
            VStack(spacing: 6) {
                gridRow("Spot", String(format: "%.0f", mtm.spot ?? 0), nil, "Entry spot", String(format: "%.0f", mtm.entrySpot ?? 0), nil)
                gridRow("Net credit", "\(String(format: "%.2f", mtm.netCredit ?? 0)) pts", Theme.green, "Cost to close", "\(String(format: "%.2f", mtm.costToClose ?? 0)) pts", Theme.orange)
                gridRow("Target", "≤ \(String(format: "%.2f", mtm.profitTargetPts ?? 0)) pts", Theme.green, "SL", "≥ \(String(format: "%.2f", mtm.slPts ?? 0)) pts", Theme.red)
                gridRow("Lots", "\(mtm.lots ?? 0) × \(mtm.lotSize ?? 0)", nil, "Updated", formattedTimestamp, nil)
            }
            .padding(12)
            .font(.system(size: 13))

            // Strikes footer
            if let shortCe = mtm.shortCe, let longCe = mtm.longCe, let shortPe = mtm.shortPe, let longPe = mtm.longPe {
                HStack(spacing: 6) {
                    Text("CE \(String(format: "%.0f", shortCe)) / \(String(format: "%.0f", longCe))")
                        .font(.system(size: 12, weight: .regular).monospacedDigit())
                    Text("•")
                    Text("PE \(String(format: "%.0f", shortPe)) / \(String(format: "%.0f", longPe))")
                        .font(.system(size: 12, weight: .regular).monospacedDigit())
                    Spacer()
                }
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
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

    private func gridRow(_ label1: String, _ value1: String, _ color1: Color? = nil, _ label2: String, _ value2: String, _ color2: Color? = nil) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label1)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                Text(value1)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(color1 ?? Theme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(label2)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                Text(value2)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(color2 ?? Theme.textPrimary)
            }
        }
    }
}

#Preview {
    MTMCard(mtm: MTMData(
        mtmInr: 82.5,
        mtmPts: 3.3,
        status: "open",
        spot: 23913.7,
        entrySpot: 23986.0,
        entryTime: "2026-05-26T10:59:17.677792",
        atm: 24000,
        netCredit: 55.65,
        costToClose: 52.35,
        profitTargetPts: 27.82,
        slPts: 111.3,
        lots: 1,
        lotSize: 25,
        shortCe: 24400,
        longCe: 24600,
        shortPe: 23600,
        longPe: 23400,
        timestamp: "2026-05-26T14:15:05.001247"
    ))
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
