import Foundation

/// Abstraction over the mobile API v1 engine operations so view models can be
/// unit-tested with a mock. `APIClient` is the production conformer; call sites
/// keep passing `appState.client` unchanged.
protocol EngineServicing {
    func listEngines() async throws -> EnginesListResponse
    func engineStatus(_ engineId: String) async throws -> EngineStatusResponse
    func engineConfig(_ engineId: String) async throws -> EngineConfigResponse
    func createEngine(_ body: CreateEngineRequest) async throws -> EngineActionResponse
    func patchEngineConfig(_ engineId: String, body: PatchEngineConfigRequest) async throws -> EngineConfigResponse
    func engineLifecycle(_ engineId: String, action: EngineLifecycleAction) async throws -> EngineActionResponse
    func deleteEngine(_ engineId: String) async throws -> EngineActionResponse
    func updateEngineToken(_ engineId: String, accessToken: String) async throws -> EngineActionResponse
    func syncEngineToken(_ engineId: String) async throws -> EngineActionResponse
    func rotateApiKey(newKey: String) async throws -> RotateKeyResponse
}

extension APIClient: EngineServicing {}
