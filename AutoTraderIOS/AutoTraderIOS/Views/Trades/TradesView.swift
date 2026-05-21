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

    private var pnlKey: String? {
        trade.keys.first { $0.lowercased().contains("pnl") || $0.lowercased().contains("p&l") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(trade.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 100, alignment: .leading)
                    Text(trade[key] ?? "")
                        .font(.caption)
                        .foregroundColor(pnlColor(for: key, value: trade[key]))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBg)
        .cornerRadius(Theme.radius)
    }

    private func pnlColor(for key: String, value: String?) -> Color {
        guard key == pnlKey, let val = value, let num = Double(val) else {
            return Theme.textPrimary
        }
        return num >= 0 ? Theme.green : Theme.red
    }
}
