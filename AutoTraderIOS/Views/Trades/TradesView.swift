import SwiftUI

struct TradesView: View {
    @EnvironmentObject var apiClient: APIClient
    @StateObject private var viewModel = TradesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.trades.isEmpty && viewModel.hasLoaded {
                    EmptyTradesView()
                } else if !viewModel.hasLoaded && viewModel.trades.isEmpty {
                    LoadingTradesView(errorMessage: viewModel.errorMessage)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(viewModel.trades.enumerated()), id: \.offset) { _, trade in
                                TradeCard(trade: trade)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .refreshable { await viewModel.refresh(using: apiClient) }
                }
            }
            .navigationTitle("Trades")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !viewModel.hasLoaded {
                Task { await viewModel.load(using: apiClient) }
            }
        }
    }
}

private struct TradeCard: View {
    let trade: [String: String]

    private let pnlKeys: Set<String> = ["pnl", "p&l", "profit_loss", "realized_pnl", "unrealized_pnl"]
    private let timeKeys: Set<String> = ["entry_time", "exit_time", "time"]

    private var orderedKeys: [String] {
        let keys = Array(trade.keys).sorted()
        let time = keys.filter { timeKeys.contains($0.lowercased()) }
        let rest = keys.filter { !timeKeys.contains($0.lowercased()) }
        return time + rest
    }

    private func isPnlKey(_ key: String) -> Bool {
        pnlKeys.contains(key.lowercased())
    }

    private func pnlColor(for value: String) -> Color {
        let cleaned = value
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let num = Double(cleaned) {
            return num >= 0 ? Theme.green : Theme.red
        }
        return Theme.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Entry time header if present
            if let entryTime = trade["entry_time"] {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(entryTime)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
                Divider().background(Theme.divider).padding(.horizontal, 14)
            }

            // Dynamic columns as chips
            TradeFieldsFlow(
                keys: orderedKeys.filter { $0 != "entry_time" },
                trade: trade,
                isPnlKey: isPnlKey,
                pnlColor: pnlColor
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

private struct TradeFieldsFlow: View {
    let keys: [String]
    let trade: [String: String]
    let isPnlKey: (String) -> Bool
    let pnlColor: (String) -> Color

    var body: some View {
        // Simple wrapping layout using flexible width chips
        _FlowLayout(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                if let value = trade[key] {
                    TradeFieldChip(
                        key: key,
                        value: value,
                        isPnl: isPnlKey(key),
                        valueColor: isPnlKey(key) ? pnlColor(value) : Theme.text
                    )
                }
            }
        }
    }
}

private struct TradeFieldChip: View {
    let key: String
    let value: String
    let isPnl: Bool
    let valueColor: Color

    var displayKey: String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayKey)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isPnl ? valueColor.opacity(0.12) : Theme.background)
        .cornerRadius(6)
    }
}

private struct _FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var height: CGFloat = 0
        var rowX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > width && rowX > 0 {
                height += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct EmptyTradesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text("No trades recorded yet.")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("Completed trades will appear here once an engine runs.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}

private struct LoadingTradesView: View {
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let error = errorMessage {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.red)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Theme.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                    .scaleEffect(1.2)
                Text("Loading trades...")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
