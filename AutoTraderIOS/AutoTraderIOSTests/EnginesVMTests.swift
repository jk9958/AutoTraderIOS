//
//  EnginesVMTests.swift
//  Unit tests for the bot view models using a mock EngineServicing (DI).
//

import Testing
import Foundation
@testable import AutoTraderIOS

/// Records calls and returns canned responses so view models can be tested
/// without a network.
final class MockEngineService: EngineServicing, @unchecked Sendable {
    var engines: [EngineInfo] = []
    var listError: Error?
    var createError: Error?
    var capturedCreate: CreateEngineRequest?
    private(set) var lifecycleCalls: [(String, EngineLifecycleAction)] = []
    private(set) var tokenUpdates: [(String, String)] = []

    func listEngines() async throws -> EnginesListResponse {
        if let listError { throw listError }
        return EnginesListResponse(ok: true, engines: engines, error: nil)
    }
    func engineStatus(_ engineId: String) async throws -> EngineStatusResponse {
        EngineStatusResponse(ok: true, engine: engines.first { $0.engineId == engineId }
            ?? EngineInfo(engineId: engineId, broker: nil, strategy: nil, status: "STOPPED", pid: nil, lastBeat: nil, stale: nil))
    }
    func engineConfig(_ engineId: String) async throws -> EngineConfigResponse {
        EngineConfigResponse(ok: true, engineId: engineId, config: .object(["params": .object(["dry_run": .bool(true)])]))
    }
    func createEngine(_ body: CreateEngineRequest) async throws -> EngineActionResponse {
        capturedCreate = body
        if let createError { throw createError }
        return EngineActionResponse(ok: true, engineId: body.engineId, status: nil, unit: nil,
                                    configPath: nil, secretsPath: nil, autostarted: body.autostart,
                                    autostartError: nil, note: nil)
    }
    func patchEngineConfig(_ engineId: String, body: PatchEngineConfigRequest) async throws -> EngineConfigResponse {
        EngineConfigResponse(ok: true, engineId: engineId, config: .object([:]))
    }
    func engineLifecycle(_ engineId: String, action: EngineLifecycleAction) async throws -> EngineActionResponse {
        lifecycleCalls.append((engineId, action))
        return EngineActionResponse(ok: true, engineId: engineId, status: action.rawValue + "ed", unit: nil,
                                    configPath: nil, secretsPath: nil, autostarted: nil, autostartError: nil, note: nil)
    }
    func deleteEngine(_ engineId: String) async throws -> EngineActionResponse {
        EngineActionResponse(ok: true, engineId: engineId, status: "deleted", unit: nil, configPath: nil,
                             secretsPath: nil, autostarted: nil, autostartError: nil, note: nil)
    }
    func updateEngineToken(_ engineId: String, accessToken: String) async throws -> EngineActionResponse {
        tokenUpdates.append((engineId, accessToken))
        return EngineActionResponse(ok: true, engineId: engineId, status: nil, unit: nil, configPath: nil,
                                    secretsPath: nil, autostarted: nil, autostartError: nil, note: nil)
    }
    private(set) var tokenSyncs: [String] = []
    var syncError: Error?
    func syncEngineToken(_ engineId: String) async throws -> EngineActionResponse {
        tokenSyncs.append(engineId)
        if let syncError { throw syncError }
        return EngineActionResponse(ok: true, engineId: engineId, status: nil, unit: nil, configPath: nil,
                                    secretsPath: nil, autostarted: nil, autostartError: nil, note: nil)
    }
    func rotateApiKey(newKey: String) async throws -> RotateKeyResponse {
        RotateKeyResponse(ok: true, updatedAt: "10:00", note: nil)
    }
}

@MainActor
struct EnginesVMTests {

    @Test func createSendsCorrectRequest() async {
        let mock = MockEngineService()
        let vm = CreateEngineVM()
        vm.engineId = "my_range_bot"
        vm.strategy = .ironCondor
        vm.broker = .kite
        vm.dryRun = true

        let ok = await vm.submit(client: mock)
        #expect(ok)
        #expect(mock.capturedCreate?.engineId == "my_range_bot")
        #expect(mock.capturedCreate?.broker == "kite")
        #expect(mock.capturedCreate?.strategy == "iron_condor")
        #expect(mock.capturedCreate?.params["dry_run"] == .bool(true))
    }

    @Test func createSurfacesFriendlyFailure() async {
        let mock = MockEngineService()
        mock.createError = APIError.unauthorized
        let vm = CreateEngineVM()
        vm.engineId = "bot_one"
        let ok = await vm.submit(client: mock)
        #expect(!ok)
        #expect(vm.banner != nil)
    }

    @Test func lifecycleActionHitsService() async {
        let mock = MockEngineService()
        let store = EnginesStore(service: { mock })
        await store.perform(.start, on: "bot_one")
        #expect(mock.lifecycleCalls.first?.0 == "bot_one")
        #expect(mock.lifecycleCalls.first?.1 == .start)
    }

    @Test func storeRefreshLoadsRunningModes() async {
        let mock = MockEngineService()
        mock.engines = [EngineInfo(engineId: "bot_one", broker: "fyers", strategy: "iron_condor",
                                   status: "RUNNING", pid: 1, lastBeat: nil, stale: false)]
        let store = EnginesStore(service: { mock })
        await store.refresh()
        // mock.engineConfig returns params.dry_run = true
        #expect(store.mode(for: "bot_one") == true)
        #expect(store.engines.count == 1)
    }

    @Test func tokenUpdateForwardsToService() async {
        let mock = MockEngineService()
        let vm = EngineDetailVM(engineId: "bot_one")
        let ok = await vm.updateToken("abc123", client: mock)
        #expect(ok)
        #expect(mock.tokenUpdates.first?.0 == "bot_one")
        #expect(mock.tokenUpdates.first?.1 == "abc123")
    }
}
