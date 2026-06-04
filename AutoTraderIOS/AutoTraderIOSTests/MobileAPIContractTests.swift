//
//  MobileAPIContractTests.swift
//  Contract tests for the mobile API v1 models — guards the snake_case encode /
//  convertFromSnakeCase decode convention documented in CLAUDE.md.
//

import Testing
import Foundation
@testable import AutoTraderIOS

struct MobileAPIContractTests {

    /// Shared decoder mirrors APIClient's `.convertFromSnakeCase` strategy.
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    // MARK: Decoding (responses)

    @Test func decodesEnginesList() throws {
        let json = """
        {"ok": true, "engines": [
          {"engine_id": "engine_fyers_01", "broker": "FYERS", "strategy": "iron_condor",
           "status": "RUNNING", "pid": 4242, "last_beat": "2026-06-04T10:00:00+05:30", "stale": false}
        ]}
        """.data(using: .utf8)!
        let resp = try decoder.decode(EnginesListResponse.self, from: json)
        #expect(resp.ok)
        let e = try #require(resp.engines.first)
        #expect(e.engineId == "engine_fyers_01")
        #expect(e.lastBeat == "2026-06-04T10:00:00+05:30")
        #expect(e.runState == .running)
    }

    @Test func staleEngineMapsToStaleState() throws {
        let json = #"{"engine_id":"e1","status":"STALE","stale":true}"#.data(using: .utf8)!
        let e = try decoder.decode(EngineInfo.self, from: json)
        #expect(e.runState == .stale)
    }

    @Test func decodesCreateResponseWithAutostart() throws {
        let json = """
        {"ok": true, "engine_id": "e1", "config_path": "config/e1.yaml",
         "secrets_path": "secrets/e1.env", "autostarted": true, "unit": "algo-engine@e1"}
        """.data(using: .utf8)!
        let resp = try decoder.decode(EngineActionResponse.self, from: json)
        #expect(resp.configPath == "config/e1.yaml")
        #expect(resp.autostarted == true)
        #expect(resp.unit == "algo-engine@e1")
    }

    @Test func decodesConfigWithNestedParams() throws {
        let json = """
        {"ok": true, "engine_id": "e1",
         "config": {"engine_id": "e1", "broker": "fyers", "strategy": "iron_condor",
                    "params": {"dry_run": true, "lots": 2, "profit_target": 0.5}}}
        """.data(using: .utf8)!
        let resp = try decoder.decode(EngineConfigResponse.self, from: json)
        let rows = resp.config.sortedObjectRows
        #expect(rows.contains { $0.key == "params" })
        // dry_run is nested under params and stays a bool
        if case .object(let root) = resp.config, case .object(let params)? = root["params"] {
            #expect(params["dry_run"] == .bool(true))
            #expect(params["lots"] == .int(2))
        } else {
            Issue.record("config did not decode as nested object")
        }
    }

    // MARK: Encoding (requests must be snake_case for the plain encoder)

    @Test func createRequestEncodesSnakeCase() throws {
        let body = CreateEngineRequest(
            engineId: "engine_kite_01", broker: "kite", strategy: "trend",
            params: ["dry_run": .bool(false)], accessToken: "tok",
            telegramBotToken: "bot", telegramChatId: "123", autostart: true
        )
        let data = try JSONEncoder().encode(body)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["engine_id"] as? String == "engine_kite_01")
        #expect(obj["access_token"] as? String == "tok")
        #expect(obj["telegram_bot_token"] as? String == "bot")
        #expect(obj["telegram_chat_id"] as? String == "123")
        #expect(obj["autostart"] as? Bool == true)
        let params = try #require(obj["params"] as? [String: Any])
        #expect(params["dry_run"] as? Bool == false)
    }

    @Test func tokenAndRotateRequestsEncodeSnakeCase() throws {
        let tokenData = try JSONEncoder().encode(EngineTokenRequest(accessToken: "abc"))
        let tokenObj = try JSONSerialization.jsonObject(with: tokenData) as? [String: Any]
        #expect(tokenObj?["access_token"] as? String == "abc")

        let rotateData = try JSONEncoder().encode(RotateKeyRequest(apiKey: "0123456789ab"))
        let rotateObj = try JSONSerialization.jsonObject(with: rotateData) as? [String: Any]
        #expect(rotateObj?["api_key"] as? String == "0123456789ab")
    }

    @Test func patchRequestEncodesParamsAndExtra() throws {
        let body = PatchEngineConfigRequest(params: ["dry_run": .bool(true)], extra: ["expiry": .string("2026-06-26")])
        let data = try JSONEncoder().encode(body)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(((obj?["params"] as? [String: Any])?["dry_run"]) as? Bool == true)
        #expect(((obj?["extra"] as? [String: Any])?["expiry"]) as? String == "2026-06-26")
    }

    // MARK: Client-side validation (mirrors server)

    @Test func engineIdValidationMatchesServerRegex() {
        #expect(EngineValidation.isValidEngineId("engine_fyers-01"))
        #expect(!EngineValidation.isValidEngineId(""))
        #expect(!EngineValidation.isValidEngineId("../escape"))
        #expect(!EngineValidation.isValidEngineId("has space"))
        #expect(!EngineValidation.isValidEngineId("dot.name"))
    }

    @Test func apiKeyLengthRule() {
        #expect(!EngineValidation.isValidApiKey("short"))
        #expect(EngineValidation.isValidApiKey("123456789012"))   // exactly 12
    }

    @Test func enumRawValuesMatchServerContract() {
        #expect(EngineStrategy.ironCondor.rawValue == "iron_condor")
        #expect(EngineStrategy.vixScalp.rawValue == "vix_scalp")
        #expect(EngineStrategy.trend.rawValue == "trend")
        #expect(EngineBroker.allCases.map(\.rawValue) == ["fyers", "kite", "tradesmart"])
        #expect(EngineLifecycleAction.restart.rawValue == "restart")
    }
}
