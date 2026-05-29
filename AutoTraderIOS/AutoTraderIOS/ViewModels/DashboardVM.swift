import SwiftUI
import Combine
import SafariServices

@MainActor
final class DashboardVM: ObservableObject {
    @Published var isStoppingEngine = false
    @Published var stopError: String?

    @Published var showFyersAuth = false
    @Published var fyersAuthURL: URL?

    @Published var showKiteAuth = false
    @Published var kiteAuthURL: URL?

    @Published var showTradesmartAuth = false
    @Published var tradesmartAuthURL: URL?

    @Published var isSavingFyersToEnv = false

    @Published var alertMessage: String?
    @Published var showAlert = false

    // MARK: - Stop Engine

    func stopEngine(appState: AppState) async {
        isStoppingEngine = true
        stopError = nil
        defer { isStoppingEngine = false }

        do {
            let resp = try await appState.client.stop()
            if resp.status == "not_running" {
                present(info: "No engine was running.")
            }
            Haptics.success()
            await appState.fetchStatus()
        } catch let err as APIError {
            stopError = err.errorDescription
            Haptics.error()
        } catch {
            stopError = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Fyers OAuth

    func openFyersAuth(appState: AppState) {
        do {
            fyersAuthURL = try appState.client.fyersAuthURL()
            showFyersAuth = true
        } catch let err as APIError {
            present(error: err.errorDescription ?? "Unknown error")
        } catch {
            present(error: error.localizedDescription)
        }
    }

    func handleFyersAuthDismiss(appState: AppState) async {
        showFyersAuth = false
        await appState.fetchStatus()
        if let status = appState.serverStatus {
            let val = status.tokens?["fyers"] ?? ""
            if !val.contains("updated") && !val.contains("loaded") && !val.contains("active") {
                present(info: "Fyers login may not have completed — try again.")
            }
        }
    }

    // MARK: - Kite OAuth

    func openKiteAuth(appState: AppState) {
        do {
            kiteAuthURL = try appState.client.kiteAuthURL()
            showKiteAuth = true
        } catch let err as APIError {
            present(error: err.errorDescription ?? "Unknown error")
        } catch {
            present(error: error.localizedDescription)
        }
    }

    func handleKiteAuthDismiss(appState: AppState) async {
        showKiteAuth = false
        await appState.fetchStatus()
        if let status = appState.serverStatus {
            let val = status.tokens?["kite"] ?? ""
            if !val.contains("updated") && !val.contains("loaded") && !val.contains("active") {
                present(info: "Kite login may not have completed — try again.")
            }
        }
    }

    // MARK: - TradeSmart OAuth

    func openTradesmartAuth(appState: AppState) {
        do {
            tradesmartAuthURL = try appState.client.tradesmartAuthURL()
            showTradesmartAuth = true
        } catch let err as APIError {
            present(error: err.errorDescription ?? "Unknown error")
        } catch {
            present(error: error.localizedDescription)
        }
    }

    func handleTradesmartAuthDismiss(appState: AppState) async {
        showTradesmartAuth = false
        await appState.fetchStatus()
    }

    // MARK: - Save Fyers Token to .env

    func saveFyersToEnv(appState: AppState) async {
        isSavingFyersToEnv = true
        defer { isSavingFyersToEnv = false }
        do {
            let resp = try await appState.client.saveFyersTokenToEnv()
            let time = resp.updatedAt.map { " at \($0)" } ?? ""
            present(info: resp.message ?? "Fyers token saved to .env\(time)")
            Haptics.success()
        } catch let err as APIError {
            present(error: err.errorDescription ?? "Unknown error")
            Haptics.error()
        } catch {
            present(error: error.localizedDescription)
            Haptics.error()
        }
    }

    // MARK: - Helpers

    private func present(error: String) {
        alertMessage = error
        showAlert = true
        Haptics.error()
    }

    private func present(info: String) {
        alertMessage = info
        showAlert = true
    }
}
