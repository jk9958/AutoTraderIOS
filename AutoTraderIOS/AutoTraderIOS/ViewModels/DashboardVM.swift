import SwiftUI
import SafariServices
import AuthenticationServices
import Combine

@MainActor
final class DashboardVM: ObservableObject {
    @Published var isStoppingEngine = false
    @Published var stopError: String?

    @Published var isSavingFyersToken = false
    @Published var isSavingKiteToken = false
    @Published var fyersTokenInput = ""
    @Published var kiteTokenInput = ""
    @Published var showFyersTokenForm = false
    @Published var showKiteTokenForm = false
    @Published var tokenSaveError: String?
    @Published var tokenSaveSuccess: String?

    @Published var showFyersAuth = false
    @Published var fyersAuthURL: URL?

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

    // MARK: - Token Save

    func saveFyersToken(appState: AppState) async {
        let token = fyersTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isSavingFyersToken = true
        tokenSaveError = nil
        tokenSaveSuccess = nil
        defer { isSavingFyersToken = false }

        do {
            let resp = try await appState.client.setToken(broker: "fyers", accessToken: token)
            tokenSaveSuccess = "Fyers token saved (\(resp.updatedAt))"
            fyersTokenInput = ""
            showFyersTokenForm = false
            Haptics.success()
            await appState.fetchStatus()
        } catch let err as APIError {
            tokenSaveError = err.errorDescription
            Haptics.error()
        } catch {
            tokenSaveError = error.localizedDescription
            Haptics.error()
        }
    }

    func saveKiteToken(appState: AppState) async {
        let token = kiteTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isSavingKiteToken = true
        tokenSaveError = nil
        tokenSaveSuccess = nil
        defer { isSavingKiteToken = false }

        do {
            let resp = try await appState.client.setToken(broker: "kite", accessToken: token)
            tokenSaveSuccess = "Kite token saved (\(resp.updatedAt))"
            kiteTokenInput = ""
            showKiteTokenForm = false
            Haptics.success()
            await appState.fetchStatus()
        } catch let err as APIError {
            tokenSaveError = err.errorDescription
            Haptics.error()
        } catch {
            tokenSaveError = error.localizedDescription
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
            let val = status.tokens["fyers"] ?? ""
            if !val.contains("updated") && !val.contains("loaded") {
                present(info: "Fyers login may not have completed — try again.")
            }
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
