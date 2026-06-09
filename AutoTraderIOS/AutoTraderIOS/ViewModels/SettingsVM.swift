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

    func testConnection(client: APIClient) async {
        testResult = .testing
        do {
            try await client.health()
            testResult = .success
            Haptics.success()
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
