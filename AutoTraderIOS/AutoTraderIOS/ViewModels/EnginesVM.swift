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

// MARK: - Engines list

@MainActor
final class EnginesVM: ObservableObject {
    @Published var state: Loadable<[EngineInfo]> = .idle
    /// engine_ids with an in-flight lifecycle action (disables their row controls).
    @Published var busy: Set<String> = []
    @Published var banner: String?

    private var loadTask: Task<Void, Never>?

    func load(client: APIClient, showSpinner: Bool = true) {
        loadTask?.cancel()
        if showSpinner, state.value == nil { state = .loading }
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let resp = try await client.listEngines()
                if Task.isCancelled { return }
                if !resp.ok, let err = resp.error {
                    self.state = .failed(err)
                } else {
                    self.state = .loaded(resp.engines)
                }
            } catch is CancellationError {
                return
            } catch let err as APIError {
                if self.state.value == nil { self.state = .failed(err.errorDescription ?? "Failed to load") }
                else { self.banner = err.errorDescription }
            } catch {
                if self.state.value == nil { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    func perform(_ action: EngineLifecycleAction, on id: String, client: APIClient) async {
        guard !busy.contains(id) else { return }   // de-dupe concurrent taps
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            _ = try await client.engineLifecycle(id, action: action)
            Haptics.success()
            load(client: client, showSpinner: false)
        } catch let err as APIError {
            banner = err.errorDescription
            Haptics.error()
        } catch {
            banner = error.localizedDescription
            Haptics.error()
        }
    }

    func delete(_ id: String, client: APIClient) async {
        guard !busy.contains(id) else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            _ = try await client.deleteEngine(id)
            Haptics.success()
            load(client: client, showSpinner: false)
        } catch let err as APIError {
            banner = err.errorDescription
            Haptics.error()
        } catch {
            banner = error.localizedDescription
            Haptics.error()
        }
    }
}

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

    func refresh(client: APIClient) async {
        if status.value == nil { status = .loading }
        if config.value == nil { config = .loading }
        async let s = loadStatus(client: client)
        async let c = loadConfig(client: client)
        _ = await (s, c)
    }

    private func loadStatus(client: APIClient) async {
        do { status = .loaded(try await client.engineStatus(engineId).engine) }
        catch let err as APIError { status = .failed(err.errorDescription ?? "Failed") }
        catch { status = .failed(error.localizedDescription) }
    }

    private func loadConfig(client: APIClient) async {
        do { config = .loaded(try await client.engineConfig(engineId).config) }
        catch let err as APIError { config = .failed(err.errorDescription ?? "Failed") }
        catch { config = .failed(error.localizedDescription) }
    }

    func lifecycle(_ action: EngineLifecycleAction, client: APIClient) async {
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
    func patchParam(_ key: String, value: JSONValue, client: APIClient) async {
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

    func updateToken(_ token: String, client: APIClient) async -> Bool {
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

    func submit(client: APIClient) async -> Bool {
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
