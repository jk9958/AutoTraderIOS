import SwiftUI
import Combine

enum TestConnectionResult {
    case none, testing, success, failure(String)
}

@MainActor
final class SettingsVM: ObservableObject {
    @Published var testResult: TestConnectionResult = .none

    // API-key rotation
    @Published var isRotating = false
    @Published var rotateMessage: String?
    @Published var rotateFailed = false

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

    /// Rotate the server API key. On success, returns the new key so the caller
    /// can persist it locally (the old key is invalid immediately after).
    func rotateKey(newKey: String, client: APIClient) async -> String? {
        guard EngineValidation.isValidApiKey(newKey) else {
            rotateFailed = true
            rotateMessage = "New key must be at least 12 characters."
            return nil
        }
        isRotating = true
        rotateFailed = false
        rotateMessage = nil
        defer { isRotating = false }
        do {
            let resp = try await client.rotateApiKey(newKey: newKey)
            rotateMessage = "Key rotated\(resp.updatedAt.map { " at \($0)" } ?? "")."
            Haptics.success()
            return newKey
        } catch let err as APIError {
            rotateFailed = true
            rotateMessage = err.errorDescription
            Haptics.error()
            return nil
        } catch {
            rotateFailed = true
            rotateMessage = error.localizedDescription
            Haptics.error()
            return nil
        }
    }
}
