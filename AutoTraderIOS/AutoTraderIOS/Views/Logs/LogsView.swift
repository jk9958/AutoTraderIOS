import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LogsVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.lines.isEmpty {
                    loadingView
                } else if vm.lines.isEmpty {
                    emptyView
                } else {
                    logContent
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onChange(of: vm.lineCount) { _, _ in vm.refresh(client: appState.client) }
            .onAppear { vm.startPolling(client: appState.client) }
            .onDisappear { vm.stopPolling() }
        }
    }

    // MARK: - Log Content

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(vm.lines.enumerated()), id: \.offset) { idx, line in
                        LogLine(index: idx, text: line)
                            .id(idx)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemBackground))
            .onChange(of: vm.lines.count) { _, _ in
                if vm.autoscroll, let last = vm.lines.indices.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading logs…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            Text("No Logs Yet")
                .font(.title3.weight(.semibold))
            Text("Engine activity will stream here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
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
                Haptics.tap()
            } label: {
                Image(systemName: "arrow.down.to.line.compact")
                    .foregroundStyle(vm.autoscroll ? Color.green : Color.secondary)
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
}

// MARK: - Log Line Row

private struct LogLine: View {
    let index: Int
    let text: String

    private var color: Color {
        let l = text.lowercased()
        if l.contains("error") || l.contains("critical") { return .red }
        if l.contains("warn")                             { return .orange }
        if l.contains("entry") || l.contains("exit") || l.contains("order") { return .green }
        return .primary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%04d", index + 1))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 34, alignment: .trailing)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 10)
    }
}
