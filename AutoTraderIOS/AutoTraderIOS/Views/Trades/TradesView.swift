import SwiftUI

struct TradesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradesVM()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Group {
                    if vm.isLoading && vm.trades.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                    } else if vm.trades.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("No trades recorded yet.")
                                .foregroundColor(Theme.textSecondary)
                        }
                    } else {
                        List {
                            ForEach(Array(vm.trades.enumerated()), id: \.offset) { _, trade in
                                TradeCard(trade: trade)
                                    .listRowBackground(Theme.cardBg)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await vm.fetch(client: appState.client)
                        }
                    }
                }
                if let err = vm.error {
                    VStack {
                        Spacer()
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Theme.red)
                            .padding()
                    }
                }
            }
            .navigationTitle("Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.fetch(client: appState.client) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Theme.blue)
                    }
                }
            }
            .onAppear {
                Task { await vm.fetch(client: appState.client) }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TradeCard: View {
    let trade: [String: String]

    private var isDryRun: Bool {
        trade["dry_run"]?.lowercased() == "true"
    }

    private var entryDate: String {
        trade["entry_date"] ?? "N/A"
    }

    private var pnlValue: String? {
        trade.values.first { val in
            val.lowercased().contains("pnl") || val.lowercased().contains("p&l")
        } ?? trade["pnl_points"]
    }

    private var pnlDouble: Double? {
        guard let pnl = pnlValue, !pnl.isEmpty else { return nil }
        return Double(pnl)
    }

    private var isProfit: Bool {
        pnlDouble ?? 0 >= 0
    }

    private var exitReason: String {
        trade["exit_reason"] ?? "N/A"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Glassmorphic header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: isDryRun ? "play.circle.fill" : "record.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isDryRun ? Theme.textSecondary : Theme.green)

                        Text(isDryRun ? "DRY RUN" : "LIVE")
                            .font(.caption.bold())
                            .foregroundColor(isDryRun ? Theme.textSecondary : Theme.green)

                        if exitReason != "N/A" && !exitReason.isEmpty {
                            Divider()
                                .frame(height: 10)
                                .opacity(0.3)

                            Text(exitReason)
                                .font(.caption.bold())
                                .foregroundColor(exitReason == "OPEN" ? Theme.blue : Theme.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(exitReason == "OPEN" ? Theme.blue.opacity(0.15) : Theme.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    Text(entryDate)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let pnl = pnlDouble {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isProfit ? Theme.green : Theme.red)

                            Text(String(format: "%.2f", abs(pnl)))
                                .font(.system(size: 16, weight: .bold).monospacedDigit())
                                .foregroundColor(isProfit ? Theme.green : Theme.red)
                        }

                        Text("P&L Points")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(10)
                    .background(
                        ZStack {
                            (isProfit ? Theme.green : Theme.red).opacity(0.12)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke((isProfit ? Theme.green : Theme.red).opacity(0.3), lineWidth: 1)
                        }
                    )
                    .cornerRadius(8)
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

            Divider()
                .background(Color.white.opacity(0.08))

            // Details in grid
            if !trade.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(trade.keys.sorted()), id: \.self) { key in
                        if !["dry_run", "entry_date", "exit_reason", "pnl_points", "pnl"].contains(key.lowercased()) && !trade[key]!.isEmpty {
                            HStack(spacing: 10) {
                                Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(trade[key] ?? "")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundColor(Theme.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.blue.opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.cardBg)
        .cornerRadius(Theme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (isDryRun ? Theme.textSecondary : Theme.green).opacity(0.3),
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
}
