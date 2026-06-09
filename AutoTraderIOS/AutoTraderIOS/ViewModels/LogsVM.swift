import SwiftUI
import Combine

@MainActor
final class LogsVM: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case engine = "Engine Logs"
        case brokerApi = "Broker API"
        var id: String { rawValue }
    }

    @Published var tab: Tab = .engine

    // MARK: - Engine logs
    @Published var selectedDate = Date()
    @Published var files: [LogFile] = []
    @Published var selectedFile: LogFile?
    @Published var lines: [String] = []
    @Published var engineLive = false
    @Published var lineCount = 300

    // MARK: - Broker API logs
    @Published var apiLines: [String] = []
    @Published var apiLive = false

    @Published var isLoading = false
    @Published var error: String?
    @Published var autoscroll = true

    private var engineLiveTask: Task<Void, Never>?
    private var apiLiveTask: Task<Void, Never>?

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var selectedYMD: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: selectedDate)
    }

    // MARK: - Engine: file list

    func loadFiles(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await client.logFiles().files
            let filtered = all.filter { f in
                if isToday { return f.compressed != true }
                if let d = f.logDate { return d == selectedYMD }
                return false
            }
            files = filtered.isEmpty ? all : filtered
            // Keep selection if still present, else pick first.
            if selectedFile == nil || !files.contains(where: { $0.id == selectedFile?.id }) {
                selectedFile = files.first
            }
            error = nil
            if selectedFile != nil { await loadSelectedFile(client: client) }
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSelectedFile(client: APIClient) async {
        guard let name = selectedFile?.name else { lines = []; return }
        do {
            lines = try await client.logFile(name: name, lines: lineCount).lines
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setEngineLive(_ on: Bool, client: APIClient) {
        engineLive = on && isToday
        engineLiveTask?.cancel(); engineLiveTask = nil
        guard engineLive else { return }
        engineLiveTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadSelectedFile(client: client)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // MARK: - Broker API

    func loadBrokerApi(client: APIClient) async {
        if apiLines.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            // newest first
            apiLines = try await client.brokerApiLog(lines: 100).lines.reversed()
            error = nil
        } catch let err as APIError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setApiLive(_ on: Bool, client: APIClient) {
        apiLive = on
        apiLiveTask?.cancel(); apiLiveTask = nil
        guard on else { return }
        apiLiveTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadBrokerApi(client: client)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopAll() {
        engineLiveTask?.cancel(); engineLiveTask = nil
        apiLiveTask?.cancel(); apiLiveTask = nil
        engineLive = false
        apiLive = false
    }
}
