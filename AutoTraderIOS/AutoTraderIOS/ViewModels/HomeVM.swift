import SwiftUI
import Combine

/// A single thing that needs the user's attention on Home.
struct HomeAlert: Identifiable {
    enum Kind { case botNotResponding(String), brokerDisconnected, systemWarning, systemFailed }
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let systemImage: String
    let actionLabel: String
}

/// Aggregates everything the Home dashboard answers: which bots run, broker
/// connection, live P&L, and system health. Partial failures degrade gracefully
/// rather than blanking the screen.
@MainActor
final class HomeVM: ObservableObject {
    @Published var engines: Loadable<[EngineInfo]> = .idle
    @Published var liveMTM: MTMData?
    @Published var marketOpen: Bool?
    @Published var health: HealthDeepResponse?
    @Published var busyStopId: String?
    @Published var banner: String?

    private var loadTask: Task<Void, Never>?

    var runningBots: [EngineInfo] { (engines.value ?? []).filter { $0.runState == .running } }
    var notRespondingBots: [EngineInfo] { (engines.value ?? []).filter { $0.runState == .stale } }
    var totalBots: Int { (engines.value ?? []).count }

    /// The bot to feature in the hero card (first running, else first not-responding).
    var primaryBot: EngineInfo? { runningBots.first ?? notRespondingBots.first }

    func refresh(client: APIClient) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            // Primary: the bot list. Secondary calls are best-effort.
            do {
                let resp = try await client.listEngines()
                if Task.isCancelled { return }
                engines = .loaded(resp.engines)
            } catch is CancellationError {
                return
            } catch {
                if engines.value == nil { engines = .failed(FriendlyError.from(error).message) }
            }
            async let mtm: () = loadMTM(client: client)
            async let hp: () = loadHealth(client: client)
            _ = await (mtm, hp)
        }
    }

    private func loadMTM(client: APIClient) async {
        do {
            let resp = try await client.mtm()
            liveMTM = resp.mtm
            marketOpen = resp.marketOpen
        } catch { /* keep last known; non-critical for Home */ }
    }

    private func loadHealth(client: APIClient) async {
        do { health = try await client.healthDeep() } catch { /* non-critical */ }
    }

    func stopPrimary(client: APIClient) async {
        guard let bot = primaryBot, busyStopId == nil else { return }
        busyStopId = bot.engineId
        defer { busyStopId = nil }
        do {
            _ = try await client.engineLifecycle(bot.engineId, action: .stop)
            Haptics.success()
            Analytics.shared.track(.botStopped)
            refresh(client: client)
        } catch {
            banner = FriendlyError.from(error).message
            Haptics.error()
        }
    }

    /// Builds the prioritized alert list from current snapshots + broker status.
    func alerts(brokerConnected: Bool) -> [HomeAlert] {
        var out: [HomeAlert] = []
        for bot in notRespondingBots {
            out.append(.init(kind: .botNotResponding(bot.engineId),
                             title: "\(BotNaming.display(bot.engineId)) isn't responding",
                             message: "It hasn't checked in recently. Restarting usually fixes this.",
                             systemImage: "exclamationmark.triangle.fill",
                             actionLabel: "Restart"))
        }
        if !brokerConnected {
            out.append(.init(kind: .brokerDisconnected,
                             title: "No broker connected",
                             message: "Connect a broker to trade with real money. Practice mode still works without one.",
                             systemImage: "building.columns",
                             actionLabel: "Connect"))
        }
        switch health?.overall {
        case .failed:
            out.append(.init(kind: .systemFailed,
                             title: "System check found a problem",
                             message: "Something the bots rely on is down. Open the system check for details.",
                             systemImage: "xmark.octagon.fill",
                             actionLabel: "View"))
        case .degraded:
            out.append(.init(kind: .systemWarning,
                             title: "System needs attention",
                             message: "Things are mostly working but one area is degraded.",
                             systemImage: "exclamationmark.triangle.fill",
                             actionLabel: "View"))
        default:
            break
        }
        return out
    }
}

/// Friendly display name for an engine_id ("my_range_bot" → "My Range Bot").
enum BotNaming {
    static func display(_ engineId: String) -> String {
        let words = engineId.replacingOccurrences(of: "-", with: "_")
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.isEmpty ? engineId : words.joined(separator: " ")
    }
}
