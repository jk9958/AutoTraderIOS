import SwiftUI
import Combine

/// Loads the server's component-level system check (`/health/deep`) and optional
/// app metrics (`/metrics/app`).
@MainActor
final class DiagnosticsVM: ObservableObject {
    @Published var health: Loadable<HealthDeepResponse> = .idle
    @Published var appMetrics: JSONValue?

    func load(client: APIClient) async {
        if health.value == nil { health = .loading }
        do {
            health = .loaded(try await client.healthDeep())
        } catch {
            if health.value == nil { health = .failed(FriendlyError.from(error).message) }
        }
        do { appMetrics = try await client.appMetrics() } catch { /* optional */ }
    }
}

/// Friendly labels + fix hints for raw server component names.
enum DiagnosticsCopy {
    static func name(_ raw: String) -> String {
        switch raw {
        case "brokers":             return "Broker connection"
        case "engines":             return "Bots"
        case "dashboard_processes": return "Background services"
        default:                     return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func fix(_ raw: String, level: HealthLevel) -> String? {
        guard level != .healthy else { return nil }
        switch raw {
        case "brokers": return "Connect a broker from More → Brokers. Logins expire daily."
        case "engines": return "A bot may have stopped responding. Open Bots and try Restart."
        default:        return "This usually clears up on its own. If it persists, contact whoever runs the server."
        }
    }
}
