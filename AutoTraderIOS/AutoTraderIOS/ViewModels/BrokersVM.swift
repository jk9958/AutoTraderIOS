import SwiftUI
import Combine

@MainActor
final class BrokersVM: ObservableObject {
    @Published var statuses: [BrokerStatus] = []
    @Published var loadError: String?
    @Published var isLoading = false

    @Published var fyersTokenInput = ""
    @Published var kiteTokenInput = ""
    @Published var tradesmartCodeInput = ""

    @Published var savingBroker: String?
    @Published var saveError: String?
    @Published var saveSuccess: String?

    @Published var showFyersAuth = false
    @Published var fyersAuthURL: URL?

    // MARK: - Health

    func reload(appState: AppState) async {
        if statuses.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            statuses = try await appState.client.brokerHealth().brokers
            loadError = nil
        } catch let err as APIError {
            loadError = err.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }

    func status(for broker: String) -> BrokerStatus? {
        statuses.first { ($0.broker ?? "").lowercased() == broker.lowercased() }
    }

    // MARK: - Token save

    func saveFyersToken(appState: AppState) async {
        await saveToken(broker: "fyers", value: fyersTokenInput, appState: appState) { self.fyersTokenInput = "" }
    }

    func saveKiteToken(appState: AppState) async {
        await saveToken(broker: "kite", value: kiteTokenInput, appState: appState) { self.kiteTokenInput = "" }
    }

    func exchangeTradesmart(appState: AppState) async {
        let code = tradesmartCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        savingBroker = "tradesmart"
        saveError = nil; saveSuccess = nil
        defer { savingBroker = nil }
        do {
            let resp = try await appState.client.exchangeTradesmart(authCode: code)
            saveSuccess = "Tradesmart token saved (\(resp.updatedAt))"
            tradesmartCodeInput = ""
            Haptics.success()
            await reload(appState: appState)
        } catch let err as APIError {
            saveError = err.errorDescription; Haptics.error()
        } catch {
            saveError = error.localizedDescription; Haptics.error()
        }
    }

    private func saveToken(broker: String, value: String, appState: AppState, clear: @escaping () -> Void) async {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        savingBroker = broker
        saveError = nil; saveSuccess = nil
        defer { savingBroker = nil }
        do {
            let resp = try await appState.client.setToken(broker: broker, accessToken: token)
            saveSuccess = "\(broker.capitalized) token saved (\(resp.updatedAt))"
            clear()
            Haptics.success()
            await reload(appState: appState)
        } catch let err as APIError {
            saveError = err.errorDescription; Haptics.error()
        } catch {
            saveError = error.localizedDescription; Haptics.error()
        }
    }

    // MARK: - Fyers OAuth

    func openFyersAuth(appState: AppState) {
        do {
            fyersAuthURL = try appState.client.fyersAuthURL()
            showFyersAuth = true
        } catch {
            saveError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func handleFyersAuthDismiss(appState: AppState) async {
        showFyersAuth = false
        await reload(appState: appState)
    }
}
