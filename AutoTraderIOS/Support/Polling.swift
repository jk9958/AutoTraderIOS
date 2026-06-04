import Foundation
import Combine

@MainActor
final class PollingManager {
    private var timer: AnyCancellable?
    private let interval: TimeInterval
    private let action: () async -> Void

    init(interval: TimeInterval = 5.0, action: @escaping () async -> Void) {
        self.interval = interval
        self.action = action
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.action() }
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func restart() {
        stop()
        start()
    }
}
