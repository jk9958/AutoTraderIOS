import SwiftUI
import Combine

/// Loadable state wrapper used across the engines screens.
enum Loadable<T> {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    var value: T? { if case .loaded(let v) = self { return v } else { return nil } }
    var isLoading: Bool { if case .loading = self { return true } else { return false } }
}

// NOTE: The bot list + lifecycle/delete now live in the shared `EnginesStore`
// (single source of truth across tabs). This file keeps the per-screen detail
// and create view models.

// MARK: - Engine detail

@MainActor
final class EngineDetailVM: ObservableObject {
    let engineId: String

    @Published var status: Loadable<EngineInfo> = .idle
    @Published var config: Loadable<JSONValue> = .idle
    @Published var busyAction: EngineLifecycleAction?
    @Published var banner: String?
    @Published var savingToken = false
    @Published var savingConfig = false

    init(engineId: String) { self.engineId = engineId }

    func refresh(client: EngineServicing) async {
        if status.value == nil { status = .loading }
        if config.value == nil { config = .loading }
        async let s = loadStatus(client: client)
        async let c = loadConfig(client: client)
        _ = await (s, c)
    }

    private func loadStatus(client: EngineServicing) async {
        do { status = .loaded(try await client.engineStatus(engineId).engine) }
        catch let err as APIError { status = .failed(err.errorDescription ?? "Failed") }
        catch { status = .failed(error.localizedDescription) }
    }

    private func loadConfig(client: EngineServicing) async {
        do { config = .loaded(try await client.engineConfig(engineId).config) }
        catch let err as APIError { config = .failed(err.errorDescription ?? "Failed") }
        catch { config = .failed(error.localizedDescription) }
    }

    func lifecycle(_ action: EngineLifecycleAction, client: EngineServicing) async {
        guard busyAction == nil else { return }
        busyAction = action
        defer { busyAction = nil }
        do {
            _ = try await client.engineLifecycle(engineId, action: action)
            Haptics.success()
            await loadStatus(client: client)
        } catch let err as APIError { banner = err.errorDescription; Haptics.error() }
        catch { banner = error.localizedDescription; Haptics.error() }
    }

    /// Merge-update a single top-level param (e.g. flip dry_run).
    func patchParam(_ key: String, value: JSONValue, client: EngineServicing) async {
        guard !savingConfig else { return }
        savingConfig = true
        defer { savingConfig = false }
        do {
            let resp = try await client.patchEngineConfig(engineId, body: .init(params: [key: value]))
            config = .loaded(resp.config)
            Haptics.success()
        } catch let err as APIError { banner = err.errorDescription; Haptics.error() }
        catch { banner = error.localizedDescription; Haptics.error() }
    }

    func updateToken(_ token: String, client: EngineServicing) async -> Bool {
        guard !savingToken else { return false }
        savingToken = true
        defer { savingToken = false }
        do {
            _ = try await client.updateEngineToken(engineId, accessToken: token)
            Haptics.success()
            return true
        } catch let err as APIError { banner = err.errorDescription; Haptics.error(); return false }
        catch { banner = error.localizedDescription; Haptics.error(); return false }
    }
}

// MARK: - Create engine

@MainActor
final class CreateEngineVM: ObservableObject {
    @Published var engineId = ""
    @Published var broker: EngineBroker = .fyers
    @Published var strategy: EngineStrategy = .ironCondor
    @Published var dryRun = true
    @Published var accessToken = ""
    @Published var telegramBotToken = ""
    @Published var telegramChatId = ""
    @Published var autostart = false

    @Published var isSubmitting = false
    @Published var banner: String?

    var idIsValid: Bool { EngineValidation.isValidEngineId(engineId) }
    var canSubmit: Bool { idIsValid && !isSubmitting }

    func submit(client: EngineServicing) async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        defer { isSubmitting = false }

        let body = CreateEngineRequest(
            engineId: engineId,
            broker: broker.rawValue,
            strategy: strategy.rawValue,
            params: ["dry_run": .bool(dryRun)],
            accessToken: accessToken,
            telegramBotToken: telegramBotToken,
            telegramChatId: telegramChatId,
            autostart: autostart
        )
        do {
            let resp = try await client.createEngine(body)
            if let e = resp.autostartError { banner = "Created, but autostart failed: \(e)" }
            Haptics.success()
            return true
        } catch let err as APIError { banner = err.errorDescription; Haptics.error(); return false }
        catch { banner = error.localizedDescription; Haptics.error(); return false }
    }
}
