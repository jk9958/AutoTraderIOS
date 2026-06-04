import Foundation

/// Crash-safe display formatting for server-supplied numbers.
///
/// `Int(Double)` TRAPS on non-finite (`NaN`/`Infinity`) or out-of-`Int`-range
/// values — which a buggy or hostile server can easily send for a P&L or strike.
/// Always route server Doubles through these helpers before display.
enum Format {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// Signed INR, grouped: `+₹1,240`, `-₹50`, or `—` for nil/non-finite.
    static func inr(_ value: Double?) -> String {
        guard let v = value, v.isFinite else { return "—" }
        let sign = v < 0 ? "-" : "+"
        let n = grouped.string(from: NSNumber(value: abs(v))) ?? String(format: "%.0f", abs(v))
        return "\(sign)₹\(n)"
    }

    /// Plain integer string, finite-safe: `19500`, or `—`. Never traps.
    static func intString(_ value: Double?) -> String {
        guard let v = value, v.isFinite else { return "—" }
        return String(format: "%.0f", v.rounded())
    }

    /// Percent from a 0…1 fraction, finite-safe: `63%`, or `—`. Never traps.
    static func percent(_ fraction: Double?) -> String {
        guard let f = fraction, f.isFinite else { return "—" }
        return String(format: "%.0f%%", f * 100)
    }
}
