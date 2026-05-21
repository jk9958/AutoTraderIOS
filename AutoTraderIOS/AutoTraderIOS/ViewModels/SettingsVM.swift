import SwiftUI
import Combine

enum TestConnectionResult {
    case none, testing, success, failure(String)
}

@MainActor
final class SettingsVM: ObservableObject {
    @Published var testResult: TestConnectionResult = .none

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
}
