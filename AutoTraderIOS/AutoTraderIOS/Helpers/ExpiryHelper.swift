import Foundation

/// Weekly expiry helpers for the Iron Condor launch form.
/// NIFTY expires Tuesday (weekday 3), SENSEX Thursday (weekday 5).
enum ExpiryHelper {
    struct Expiry: Hashable, Identifiable {
        let label: String   // human-readable, e.g. "Tue 17 Jun 2026"
        let fyers: String   // Fyers code, e.g. "26617"
        var id: String { fyers }
    }

    static func weeklyExpiries(instrument: String, count: Int = 4) -> [Expiry] {
        let targetWeekday = instrument.lowercased() == "sensex" ? 5 : 3  // Thu=5, Tue=3
        var out: [Expiry] = []
        let cal = Calendar.current
        var d = cal.startOfDay(for: Date())
        // Include today if it matches and it is still that weekday.
        if cal.component(.weekday, from: d) == targetWeekday {
            out.append(Expiry(label: formatted(d), fyers: fyersCode(d)))
        }
        while out.count < count {
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
            if cal.component(.weekday, from: d) == targetWeekday {
                out.append(Expiry(label: formatted(d), fyers: fyersCode(d)))
            }
        }
        return out
    }

    private static func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: d)
    }

    /// Fyers expiry code: YY + month-code + DD.
    /// Months 1–9 → digit; Oct/Nov/Dec → O/N/D.
    static func fyersCode(_ d: Date) -> String {
        let c = Calendar.current
        let yy = String(c.component(.year, from: d) % 100)
        let m = c.component(.month, from: d)
        let dd = String(format: "%02d", c.component(.day, from: d))
        let mc = m <= 9 ? String(m) : ["O", "N", "D"][m - 10]
        return yy + mc + dd
    }
}
