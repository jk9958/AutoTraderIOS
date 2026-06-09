import SwiftUI
import Combine

struct DailyPnL: Identifiable {
    let day: Date
    let pnl: Double
    var cumulative: Double = 0
    var id: Date { day }
}

@MainActor
final class PnLVM: ObservableObject {
    @Published var daily: [DailyPnL] = []
    @Published var totalTrades = 0
    @Published var wins = 0
    @Published var totalPnL: Double = 0
    @Published var isLoading = false
    @Published var error: String?

    var winRate: Double { totalTrades == 0 ? 0 : Double(wins) / Double(totalTrades) }

    func load(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let trades = try await appState.client.trades().trades
            process(trades)
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func process(_ trades: [[String: AnyCodable]]) {
        totalTrades = trades.count
        wins = 0
        totalPnL = 0
        var byDay: [Date: Double] = [:]
        let cal = Calendar.current

        for t in trades {
            let pnl = Self.pnl(t)
            totalPnL += pnl
            if pnl > 0 { wins += 1 }
            let day = cal.startOfDay(for: Self.date(t) ?? Date())
            byDay[day, default: 0] += pnl
        }

        var running: Double = 0
        daily = byDay.keys.sorted().map { day in
            running += byDay[day]!
            return DailyPnL(day: day, pnl: byDay[day]!, cumulative: running)
        }
    }

    // MARK: - Defensive field extraction

    private static let pnlKeys = ["pnl", "realized_pnl", "net_pnl", "profit", "pl", "p_l"]
    private static let dateKeys = ["exit_time", "exit_timestamp", "timestamp", "date", "entry_time", "time"]

    private static func pnl(_ t: [String: AnyCodable]) -> Double {
        for k in pnlKeys {
            if let v = t[k] {
                switch v {
                case .double(let d): return d
                case .int(let i): return Double(i)
                case .string(let s): if let d = Double(s) { return d }
                default: break
                }
            }
        }
        return 0
    }

    private static func date(_ t: [String: AnyCodable]) -> Date? {
        for k in dateKeys {
            if case .string(let s)? = t[k], let d = parseDate(s) { return d }
        }
        return nil
    }

    private static let formatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyyMMdd"].map {
            let f = DateFormatter(); f.dateFormat = $0; f.locale = Locale(identifier: "en_US_POSIX"); return f
        }
    }()

    private static func parseDate(_ s: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: s) { return iso }
        for f in formatters { if let d = f.date(from: s) { return d } }
        return nil
    }
}
