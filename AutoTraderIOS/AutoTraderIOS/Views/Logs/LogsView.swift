import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LogsVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.lines.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading logs…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if vm.lines.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("No Logs")
                            .font(.headline)
                        Text("Engine activity will appear here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(vm.lines.enumerated()), id: \.offset) { idx, line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(String(format: "%04d", idx + 1))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 32, alignment: .trailing)
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
                        .onChange(of: vm.lines.count) { _, _ in
                            if vm.autoscroll, let last = vm.lines.indices.last {
                                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Log type", selection: Binding(
                        get: { vm.logType },
                        set: { vm.switchType(to: $0, client: appState.client) }
                    )) {
                        ForEach(LogType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        vm.autoscroll.toggle()
                    } label: {
                        Image(systemName: "arrow.down.to.line.compact")
                            .foregroundStyle(vm.autoscroll ? Color.green : Color.gray)
                    }

                    Menu {
                        Picker("Lines", selection: $vm.lineCount) {
                            Text("50 lines").tag(50)
                            Text("100 lines").tag(100)
                            Text("200 lines").tag(200)
                            Text("500 lines").tag(500)
                        }
                        Divider()
                        Button(role: .destructive) {
                            vm.clearLogs(client: appState.client)
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }

                    Button {
                        vm.refresh(client: appState.client)
                    } label: {
                        if vm.isClearing {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onChange(of: vm.lineCount) { _, _ in
                vm.refresh(client: appState.client)
            }
            .onAppear { vm.startPolling(client: appState.client) }
            .onDisappear { vm.stopPolling() }
        }
    }

    private func lineColor(_ line: String) -> Color {
        let l = line.lowercased()
        if l.contains("error") || l.contains("critical") { return .red }
        if l.contains("warn") { return .orange }
        if l.contains("entry") || l.contains("exit") || l.contains("order") { return .green }
        return .primary
    }
}
