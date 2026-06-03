import SwiftUI

struct TrendTradesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: TrendAgentVM

    @State private var mode: Mode = .trades
    @State private var trades: [[String: String]] = []
    @State private var logs: [String] = []
    @State private var isLoading = false

    enum Mode: String, CaseIterable { case trades = "Trades", logs = "Logs" }

    var body: some View {
        Group {
            switch mode {
            case .trades: tradesList
            case .logs:   logsList
            }
        }
        .navigationTitle("Trend Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .task(id: mode) { await load() }
    }

    // MARK: - Trades

    private var tradesList: some View {
        Group {
            if trades.isEmpty {
                emptyState(icon: "list.bullet.rectangle", title: "No Trades Yet")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(trades.enumerated()), id: \.offset) { _, t in
                            TrendTradeRow(trade: t)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Logs

    private var logsList: some View {
        Group {
            if logs.isEmpty {
                emptyState(icon: "doc.text", title: "No Logs Yet")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { idx, line in
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(format: "%04d", idx + 1))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                                    .frame(width: 34, alignment: .trailing)
                                Text(line)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(logColor(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 3).padding(.horizontal, 10)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String) -> some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView().scaleEffect(1.2)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 46, weight: .thin))
                    .foregroundStyle(.secondary)
                Text(title).font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case .trades:
                trades = try await appState.client.trendAgentTrades().trades ?? []
            case .logs:
                logs = try await appState.client.trendAgentLogs().lines
            }
        } catch {
            // keep previous data on failure
        }
    }

    private func logColor(_ line: String) -> Color {
        let l = line.lowercased()
        if l.contains("error") || l.contains("critical") { return .red }
        if l.contains("warn") { return .orange }
        if l.contains("entry") || l.contains("exit") || l.contains("buy") || l.contains("t1") || l.contains("t2") { return .green }
        return .primary
    }
}

// MARK: - Trend Trade Row

private struct TrendTradeRow: View {
    let trade: [String: String]

    private var action: String { trade["action"] ?? "" }
    private var symbol: String { trade["tradingsymbol"] ?? "—" }
    private var optionType: String { trade["option_type"] ?? "" }
    private var status: String { trade["status"] ?? "" }
    private var reason: String { trade["reason"] ?? "" }
    private var time: String {
        let raw = trade["timestamp"] ?? ""
        guard raw.contains("T") else { return raw }
        return String(raw.split(separator: "T").last?.prefix(8) ?? "")
    }
    private var pnl: Double? {
        guard let v = trade["pnl"], !v.isEmpty else { return nil }
        return Double(v)
    }

    private var actionColor: Color {
        switch action {
        case "ENTRY": return .blue
        case "PARTIAL_T1": return .teal
        case "EXIT": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(action)
                    .font(.caption.bold())
                    .foregroundStyle(actionColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(actionColor.opacity(0.15)))
                Spacer()
                if let pnl {
                    Text((pnl >= 0 ? "+₹" : "-₹") + String(format: "%.0f", abs(pnl)))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }
            .padding(14)

            Divider().padding(.horizontal, 14)

            HStack(spacing: 8) {
                Text(symbol).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                if !optionType.isEmpty {
                    Text(optionType).font(.caption2.bold())
                        .foregroundStyle(optionType == "CE" ? .green : .red)
                }
                Spacer()
                if !reason.isEmpty {
                    Text(reason).font(.caption2).foregroundStyle(.secondary)
                }
                Text(time).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .thinGlassCard()
    }
}
