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
            // Header with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    isDryRun ? Color(red: 0.3, green: 0.3, blue: 0.35) : Color(red: 0.1, green: 0.25, blue: 0.15),
                    isDryRun ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.08, green: 0.2, blue: 0.12)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 1)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: isDryRun ? "play.circle.fill" : "record.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isDryRun ? Color(red: 0.7, green: 0.7, blue: 0.7) : Color(red: 0.0, green: 0.8, blue: 0.4))

                        Text(isDryRun ? "DRY RUN" : "LIVE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(isDryRun ? Color(red: 0.7, green: 0.7, blue: 0.7) : Color(red: 0.0, green: 0.8, blue: 0.4))

                        Divider()
                            .frame(height: 12)
                            .opacity(0.5)

                        if exitReason != "N/A" && !exitReason.isEmpty {
                            Text(exitReason)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(exitReason == "OPEN" ? Color(red: 0.2, green: 0.6, blue: 1.0) : Color(red: 0.9, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(exitReason == "OPEN" ? Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.2) : Color(red: 0.9, green: 0.4, blue: 0.2).opacity(0.2))
                                .cornerRadius(3)
                        }
                    }

                    Text(entryDate)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let pnl = pnlDouble {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isProfit ? Color(red: 0.0, green: 0.9, blue: 0.3) : Color(red: 1.0, green: 0.3, blue: 0.3))

                            Text(String(format: "%.2f", abs(pnl)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isProfit ? Color(red: 0.0, green: 0.9, blue: 0.3) : Color(red: 1.0, green: 0.3, blue: 0.3))
                        }

                        Text("P&L")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(10)
                    .background(isProfit ? Color(red: 0.0, green: 0.9, blue: 0.3).opacity(0.15) : Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(14)

            // Divider
            Divider()
                .background(Color(white: 0.15))

            // Details Grid
            VStack(spacing: 10) {
                ForEach(Array(trade.keys.sorted()), id: \.self) { key in
                    if !["dry_run", "entry_date", "exit_reason", "pnl_points", "pnl"].contains(key.lowercased()) && !trade[key]!.isEmpty {
                        HStack(spacing: 12) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(trade[key] ?? "")
                                .font(.caption)
                                .foregroundColor(Theme.blue)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.15, green: 0.35, blue: 0.6).opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.cardBg)
        .cornerRadius(Theme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            isDryRun ? Color(red: 0.4, green: 0.4, blue: 0.5) : Color(red: 0.0, green: 0.8, blue: 0.4),
                            Color(white: 0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
