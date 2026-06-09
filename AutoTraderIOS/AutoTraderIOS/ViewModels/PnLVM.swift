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

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func load(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let days = try await appState.client.pnlDaily()
            process(days)
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func process(_ days: [PnLDay]) {
        let sorted = days.sorted { $0.date < $1.date }
        totalTrades = sorted.reduce(0) { $0 + ($1.trades ?? 0) }
        wins = sorted.reduce(0) { $0 + ($1.winners ?? 0) }
        totalPnL = sorted.reduce(0) { $0 + ($1.pnlInr ?? 0) }

        var running: Double = 0
        daily = sorted.compactMap { d in
            guard let date = Self.dayFormatter.date(from: d.date) else { return nil }
            running += d.pnlInr ?? 0
            return DailyPnL(day: date, pnl: d.pnlInr ?? 0, cumulative: running)
        }
    }
}
