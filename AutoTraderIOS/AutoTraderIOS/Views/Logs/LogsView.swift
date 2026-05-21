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
                    HStack {
                        if !vm.source.isEmpty {
                            Text("Source: \(vm.source)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Toggle("Auto-scroll", isOn: $vm.autoscroll)
                            .toggleStyle(SwitchToggleStyle(tint: Theme.green))
                            .labelsHidden()
                        Text("Auto")
                            .font(.caption)
                            .foregroundColor(vm.autoscroll ? Theme.green : Theme.textSecondary)

                        Picker("Lines", selection: $vm.lineCount) {
                            Text("50").tag(50)
                            Text("100").tag(100)
                            Text("200").tag(200)
                            Text("500").tag(500)
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.blue)
                        .onChange(of: vm.lineCount) { _, _ in
                            vm.refresh(client: appState.client)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.cardBg)

                    if vm.isLoading && vm.lines.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                        Spacer()
                    } else if vm.lines.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("No logs yet.")
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(vm.lines.enumerated()), id: \.offset) { idx, line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(lineColor(line))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(idx)
                                    }
                                }
                                .padding(12)
                            }
                            .onChange(of: vm.lines.count) { _, _ in
                                if vm.autoscroll, let last = vm.lines.indices.last {
                                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    if let err = vm.error {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Theme.red)
                            .padding(8)
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
