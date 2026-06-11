import SwiftUI
import Combine

enum TestConnectionResult {
    case none, testing, success, failure(String)
}

enum RotateState: Equatable {
    case idle, rotating, success, failure(String)
}

@MainActor
final class SettingsVM: ObservableObject {
    @Published var testResult: TestConnectionResult = .none
    @Published var rotateState: RotateState = .idle

    /// Two-stage check: `/health` proves the server is reachable (it stays public
    /// behind the login gate), then a gated endpoint proves the API key is
    /// accepted. Without the second stage a missing/wrong key reports success.
    func testConnection(client: APIClient, hasAPIKey: Bool) async {
        testResult = .testing
        // 1) Reachability.
        do {
            try await client.health()
        } catch let err as APIError {
            testResult = .failure(err.errorDescription ?? "Unknown error")
            Haptics.error()
            return
        } catch {
            testResult = .failure(error.localizedDescription)
            Haptics.error()
            return
        }
        // 2) Auth — the login gate 401s every other endpoint without a valid key.
        do {
            try await client.verifyAuth()
            testResult = .success
            Haptics.success()
        } catch APIError.unauthorized {
            testResult = .failure(hasAPIKey
                ? "Server reachable, but the API key was rejected (401)."
                : "Server reachable, but it requires an API key.")
            Haptics.error()
        } catch let err as APIError {
            testResult = .failure(err.errorDescription ?? "Unknown error")
            Haptics.error()
        } catch {
            testResult = .failure(error.localizedDescription)
            Haptics.error()
        }
    }

    /// Rotates the server key, then persists it locally (caller updates Keychain via AppState).
    func rotate(newKey: String, appState: AppState) async {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else {
            rotateState = .failure("Key must be at least 12 characters.")
            return
        }
        rotateState = .rotating
        do {
            try await appState.client.rotateApiKey(newKey: trimmed)
            appState.apiKey = trimmed   // updates Keychain + rebuilds client
            rotateState = .success
            Haptics.success()
        } catch let err as APIError {
            rotateState = .failure(err.errorDescription ?? "Unknown error")
            Haptics.error()
        } catch {
            rotateState = .failure(error.localizedDescription)
            Haptics.error()
        }
    }
}
