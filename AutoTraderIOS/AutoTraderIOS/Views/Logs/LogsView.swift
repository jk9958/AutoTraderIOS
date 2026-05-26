import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LogsVM()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Controls bar
                    HStack(spacing: 12) {
                        if !vm.source.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(vm.source)
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.glassAccent)
                            .cornerRadius(6)
                        }
                        Spacer()

                        HStack(spacing: 8) {
                            Toggle("", isOn: $vm.autoscroll)
                                .toggleStyle(SwitchToggleStyle(tint: Theme.green))
                                .scaleEffect(0.8, anchor: .center)

                            Text("Auto")
                                .font(.caption.bold())
                                .foregroundColor(vm.autoscroll ? Theme.green : Theme.textSecondary)
                        }

                        Picker("Lines", selection: $vm.lineCount) {
                            Text("50").tag(50)
                            Text("100").tag(100)
                            Text("200").tag(200)
                            Text("500").tag(500)
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.blue)
                        .font(.caption.bold())
                        .onChange(of: vm.lineCount) { _, _ in
                            vm.refresh(client: appState.client)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            Theme.glassBg
                            Divider().background(Color.white.opacity(0.08))
                        }
                    )

                    if vm.isLoading && vm.lines.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Theme.blue)
                            Text("Loading logs…")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else if vm.lines.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("No logs yet")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Text("Engine activity will appear here")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(vm.lines.enumerated()), id: \.offset) { idx, line in
                                            HStack(spacing: 8) {
                                                Text(String(format: "%04d", idx + 1))
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                                                    .frame(width: 30, alignment: .trailing)

                                                Text(line)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(lineColor(line))
                                                    .frame(maxWidth: .infinity, alignment: .leading)

                                                Spacer()
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(idx % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
                                            .id(idx)
                                        }
                                    }
                                }
                            }
                            .background(Theme.glassBg)
                            .cornerRadius(Theme.radius)
                            .padding(12)
                            .onChange(of: vm.lines.count) { _, _ in
                                if vm.autoscroll, let last = vm.lines.indices.last {
                                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    if let err = vm.error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Theme.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(Theme.red)
                            Spacer()
                        }
                        .padding(10)
                        .background(Theme.red.opacity(0.12))
                        .cornerRadius(8)
                        .padding(12)
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.refresh(client: appState.client)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Theme.blue)
                    }
                }
            }
            .onAppear {
                vm.startPolling(client: appState.client)
            }
            .onDisappear {
                vm.stopPolling()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func lineColor(_ line: String) -> Color {
        let l = line.lowercased()
        if l.contains("error") || l.contains("critical") { return Theme.red }
        if l.contains("warn") { return Theme.orange }
        if l.contains("entry") || l.contains("exit") || l.contains("order") { return Theme.green }
        return Theme.textPrimary
    }
}
