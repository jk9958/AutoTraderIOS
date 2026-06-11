import Foundation
import BackgroundTasks
import UserNotifications
import os.log

/// Schedules a periodic background refresh that polls `/health/deep` and fires a
/// local notification if overall status becomes DEGRADED/FAILED.
///
/// The task builds its own `APIClient` from persisted settings (server URL +
/// Keychain API key) so it never needs a live `AppState`.
enum BackgroundHealthManager {
    static let taskIdentifier = "com.autotrader.ios.health-refresh"
    private static let logger = Logger(subsystem: "com.autotrader.ios", category: "BGHealth")
    private static let lastStatusKey = "bgLastHealthStatus"

    /// Register the task handler. Must be called before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            handle(task: refresh)
        }
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            logger.debug("Notification permission granted=\(granted)")
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // ≥15 min
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Scheduled background health refresh")
        } catch {
            logger.error("Failed to schedule BG task: \(error.localizedDescription)")
        }
    }

    private static func makeClient() -> APIClient {
        let url = UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://trader.allweatheralgo.com"
        var client = APIClient(baseURL: url)
        client.apiKey = KeychainHelper.apiKey ?? ""
        return client
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule() // chain the next one

        let work = Task {
            await checkHealth()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    private static func checkHealth() async {
        do {
            let health = try await makeClient().healthDeep()
            let status = (health.status ?? "").uppercased()
            let degraded = status.contains("DEGRAD") || status.contains("FAIL") || status.contains("DOWN")
            let last = UserDefaults.standard.string(forKey: lastStatusKey)
            UserDefaults.standard.set(status, forKey: lastStatusKey)
            if degraded && last != status {
                let failing = health.components.filter { $0.ok == false }.map(\.name)
                notify(status: status, failing: failing)
            }
        } catch {
            logger.error("BG health check failed: \(error.localizedDescription)")
        }
    }

    private static func notify(status: String, failing: [String]) {
        let content = UNMutableNotificationContent()
        content.title = "Trading server \(status)"
        content.body = failing.isEmpty ? "A component is unhealthy." : "Affected: \(failing.joined(separator: ", "))"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
