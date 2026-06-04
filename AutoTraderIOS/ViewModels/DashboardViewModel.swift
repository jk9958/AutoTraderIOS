import SwiftUI
import Combine
import AuthenticationServices

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var status: ServerStatus? = nil
    @Published var isLoading: Bool = false
    @Published var connectionError: String? = nil
    @Published var hasHadFirstLoad: Bool = false
    @Published var alertMessage: String? = nil
    @Published var alertTitle: String = "Error"
    @Published var showAlert: Bool = false
    @Published var showStopConfirmation: Bool = false
    @Published var isStoppingEngine: Bool = false
    @Published var isFyersLoginLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var showSettings: Bool = false

    private var pollingManager: PollingManager?
    private var authSession: ASWebAuthenticationSession?
    private var toastTask: Task<Void, Never>? = nil

    // MARK: - Polling

    func startPolling(using apiClient: APIClient) {
        guard pollingManager == nil else { return }
        pollingManager = PollingManager(interval: 5.0) { [weak self] in
            await self?.pollStatus(using: apiClient)
        }
        pollingManager?.start()
    }

    func stopPolling() {
        pollingManager?.stop()
        pollingManager = nil
    }

    private func pollStatus(using apiClient: APIClient) async {
        do {
            let newStatus = try await apiClient.fetchStatus()
            status = newStatus
            if !hasHadFirstLoad { hasHadFirstLoad = true }
            if connectionError != nil { connectionError = nil }
        } catch let apiError as APIError {
            if apiError.isTransport {
                connectionError = apiError.errorDescription
            }
        } catch {
            // silent
        }
    }

    // MARK: - Refresh

    func refresh(using apiClient: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = try await apiClient.fetchStatus()
            hasHadFirstLoad = true
            connectionError = nil
        } catch let apiError as APIError {
            connectionError = apiError.errorDescription
        } catch {
            connectionError = error.localizedDescription
        }
    }

    // MARK: - Stop Engine

    func stopEngine(using apiClient: APIClient) async {
        isStoppingEngine = true
        defer { isStoppingEngine = false }
        do {
            let result = try await apiClient.stopEngine()
            if result.status == "not_running" {
                showToast("No engine was running.")
            } else {
                Haptics.success()
                showToast("Engine stopped.")
            }
            await refresh(using: apiClient)
        } catch let apiError as APIError {
            Haptics.error()
            showError(apiError.errorDescription ?? "Failed to stop engine.")
        } catch {
            Haptics.error()
            showError(error.localizedDescription)
        }
    }

    // MARK: - Fyers OAuth

    func loginWithFyers(presentationAnchor: ASPresentationAnchor, apiClient: APIClient) {
        isFyersLoginLoading = true
        guard let authURL = try? apiClient.fyersAuthURL() else {
            isFyersLoginLoading = false
            showError("Invalid server URL for Fyers auth.")
            return
        }

        let previousFyersToken = status?.tokens["fyers"]

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: nil
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.isFyersLoginLoading = false
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    return
                }
                await self.refresh(using: apiClient)
                let newFyersToken = self.status?.tokens["fyers"]
                if previousFyersToken == newFyersToken {
                    self.showError("Fyers login may not have completed — try again.")
                } else if newFyersToken != nil {
                    Haptics.success()
                    self.showToast("Fyers token updated successfully!")
                }
            }
        }
        session.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)
        session.prefersEphemeralWebBrowserSession = false
        self.authSession = session
        session.start()
    }

    // MARK: - Manual Token

    func saveToken(broker: String, token: String, using apiClient: APIClient) async {
        guard !token.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("Token must not be empty.")
            return
        }
        do {
            let response = try await apiClient.postToken(broker: broker, accessToken: token)
            Haptics.success()
            showToast("\(response.broker.capitalized) token saved.")
            await refresh(using: apiClient)
        } catch let apiError as APIError {
            Haptics.error()
            showError(apiError.errorDescription ?? "Failed to save token.")
        } catch {
            Haptics.error()
            showError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Presentation Context

final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
