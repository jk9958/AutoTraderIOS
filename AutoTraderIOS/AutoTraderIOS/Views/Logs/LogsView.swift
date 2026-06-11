import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LogsVM()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $vm.tab) {
                    ForEach(LogsVM.Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch vm.tab {
                case .engine: engineLogs
                case .brokerApi: brokerApiLogs
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: vm.tab) { await loadForTab() }
            .onDisappear { vm.stopAll() }
            .onChange(of: vm.selectedDate) { _, _ in
                vm.setEngineLive(false, client: appState.client)
                Task { await vm.loadFiles(client: appState.client) }
            }
            .onChange(of: vm.selectedFile) { _, _ in
                Task { await vm.loadSelectedFile(client: appState.client) }
            }
        }
    }

    private func loadForTab() async {
        switch vm.tab {
        case .engine: await vm.loadFiles(client: appState.client)
        case .brokerApi: await vm.loadBrokerApi(client: appState.client)
        }
    }

    // MARK: - Engine Logs

    private var engineLogs: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                DatePicker(
                    "Date", selection: $vm.selectedDate,
                    in: ...Date(), displayedComponents: .date
                )
                if !vm.files.isEmpty {
                    Picker("File", selection: $vm.selectedFile) {
                        ForEach(vm.files) { file in
                            Text(file.name).tag(Optional(file))
                        }
                    }
                }
                if Calendar.current.isDateInToday(vm.selectedDate) {
                    Toggle("Live (5s)", isOn: Binding(
                        get: { vm.engineLive },
                        set: { vm.setEngineLive($0, client: appState.client) }
                    ))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            logViewer(lines: vm.lines, numbered: true)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.loadSelectedFile(client: appState.client) }
                } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    // MARK: - Broker API Logs

    private var brokerApiLogs: some View {
        VStack(spacing: 0) {
            Toggle("Live (5s)", isOn: Binding(
                get: { vm.apiLive },
                set: { vm.setApiLive($0, client: appState.client) }
            ))
            .padding(.horizontal)
            .padding(.bottom, 8)

            logViewer(lines: vm.apiLines, numbered: false)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.loadBrokerApi(client: appState.client) }
                } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    // MARK: - Shared viewer

    @ViewBuilder
    private func logViewer(lines: [String], numbered: Bool) -> some View {
        if vm.isLoading && lines.isEmpty {
            VStack { ProgressView(); Text("Loading…").font(.caption).foregroundStyle(.secondary) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error, lines.isEmpty {
            ContentUnavailableView("Couldn't load logs", systemImage: "exclamationmark.triangle", description: Text(err))
        } else if lines.isEmpty {
            ContentUnavailableView("No log lines", systemImage: "doc.text")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                            HStack(alignment: .top, spacing: 8) {
                                if numbered {
                                    Text(String(format: "%04d", idx + 1))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 32, alignment: .trailing)
                                }
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(lineColor(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 12)
                            .background(idx % 2 == 0 ? Color.clear : Color.white.opacity(0.03))
                            .id(idx)
                        }
                    }
                }
                .onChange(of: lines.count) { _, _ in
                    if vm.autoscroll, numbered, let last = lines.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private func lineColor(_ line: String) -> Color {
        let l = line.lowercased()
        if l.contains("resp") && (l.contains(" 4") || l.contains(" 5") || l.contains("error")) { return .red }
        if l.contains("error") || l.contains("critical") { return .red }
        if l.contains("warn") { return .orange }
        if l.contains("resp") && l.contains(" 2") { return .green }
        if l.contains("req") { return .primary }
        if l.contains("entry") || l.contains("exit") || l.contains("order") { return .green }
        return .primary
    }
}
