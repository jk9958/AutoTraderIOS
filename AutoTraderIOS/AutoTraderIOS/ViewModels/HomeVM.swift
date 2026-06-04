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

/// Home aggregates the shared bot list (`EnginesStore`) with live P&L (`/mtm`) and
/// system health (`/health/deep`). The bot list itself lives in the store (single
/// source of truth); this VM owns only the auxiliary signals and polls them while
/// Home is on screen.
@MainActor
final class HomeVM: ObservableObject {
    @Published var liveMTM: MTMData?
    @Published var marketOpen: Bool?
    @Published var health: HealthDeepResponse?
    @Published var busyStopId: String?
    @Published var banner: String?

    private var auxTask: Task<Void, Never>?

    // MARK: Derived from the shared store

    func runningBots(_ engines: [EngineInfo]) -> [EngineInfo] { engines.filter { $0.runState == .running } }
    func notRespondingBots(_ engines: [EngineInfo]) -> [EngineInfo] { engines.filter { $0.runState == .stale } }
    /// Featured bot: first running, else first not-responding.
    func primaryBot(_ engines: [EngineInfo]) -> EngineInfo? {
        runningBots(engines).first ?? notRespondingBots(engines).first
    }

    // MARK: Auxiliary polling (live P&L + health)

    func startAuxPolling(client: APIClient) {
        guard auxTask == nil else { return }
        auxTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAux(client: client)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopAuxPolling() {
        auxTask?.cancel()
        auxTask = nil
    }

    func refreshAux(client: APIClient) async {
        async let mtm: () = loadMTM(client: client)
        async let hp: () = loadHealth(client: client)
        _ = await (mtm, hp)
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

    // MARK: Actions

    func stop(_ bot: EngineInfo, store: EnginesStore) async {
        guard busyStopId == nil else { return }
        busyStopId = bot.engineId
        defer { busyStopId = nil }
        await store.perform(.stop, on: bot.engineId)
        Analytics.shared.track(.botStopped)
    }

    func restart(_ id: String, store: EnginesStore) async {
        await store.perform(.restart, on: id)
    }

    // MARK: Alerts

    func alerts(engines: [EngineInfo], brokerConnected: Bool) -> [HomeAlert] {
        var out: [HomeAlert] = []
        for bot in notRespondingBots(engines) {
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
