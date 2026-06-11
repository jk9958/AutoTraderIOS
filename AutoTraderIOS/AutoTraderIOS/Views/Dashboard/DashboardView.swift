import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardVM()
    @State private var showSettings = false
    @State private var elapsed = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var status: ServerStatus? { appState.serverStatus }

    var body: some View {
        NavigationStack {
            List {
                // Connection error
                if appState.connectionState == .disconnected, let err = appState.connectionError {
                    Section {
                        Label(err, systemImage: "wifi.slash")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                        Button("Retry") { appState.refreshNow() }
                    }
                }

                if let s = status {
                    // Engine status
                    Section {
                        HStack {
                            Label {
                                Text(s.running ? "Running" : "Stopped")
                                    .foregroundStyle(s.running ? Color.green : Color.gray)
                            } icon: {
                                Image(systemName: s.running ? "circle.fill" : "circle")
                                    .foregroundStyle(s.running ? Color.green : Color.gray)
                                    .font(.caption)
                            }
                            Spacer()
                            Text(s.isPaperTrading ? "Paper" : "Live")
                                .font(.caption.bold())
                                .foregroundStyle(s.isPaperTrading ? .orange : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((s.isPaperTrading ? Color.orange : Color.red).opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let engine = s.engine, !engine.isEmpty {
                            LabeledContent("Strategy", value: engine)
                        }

                        if s.running, let startedAt = s.startedAt {
                            LabeledContent("Started") {
                                Text(formattedStartTime(startedAt))
                                    .monospacedDigit()
                            }
                            if !elapsed.isEmpty {
                                LabeledContent("Uptime") {
                                    Text(elapsed)
                                        .monospacedDigit()
                                        .foregroundStyle(.green)
                                }
                            }
                        }

                        if let code = s.exitCode, code != 0, !s.running {
                            Label("Exit code \(code) — check logs", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    } header: {
                        Text("Engine")
                    }

                    // Stop engine
                    Section {
                        if let err = vm.stopError {
                            Label(err, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                        Button(role: .destructive) {
                            Task { await vm.stopEngine(appState: appState) }
                        } label: {
                            HStack {
                                Spacer()
                                if vm.isStoppingEngine {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                        .padding(.trailing, 6)
                                }
                                Text(vm.isStoppingEngine ? "Stopping…" : "Stop Engine")
                                Spacer()
                            }
                        }
                        .disabled(!s.running || vm.isStoppingEngine)
                    }

                    // Broker auth
                    Section {
                        tokenStatusRow(broker: "fyers", label: "Fyers")
                        tokenStatusRow(broker: "kite", label: "Kite")

                        Button {
                            vm.openFyersAuth(appState: appState)
                        } label: {
                            Label("Login with Fyers", systemImage: "arrow.up.right.square")
                        }

                        DisclosureGroup(isExpanded: $vm.showFyersTokenForm) {
                            SecureField("Fyers access token", text: $vm.fyersTokenInput)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Button {
                                Task { await vm.saveFyersToken(appState: appState) }
                            } label: {
                                HStack {
                                    Spacer()
                                    if vm.isSavingFyersToken {
                                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                                    } else {
                                        Text("Save Fyers Token")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(vm.isSavingFyersToken || vm.fyersTokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        } label: {
                            Label("Paste Fyers Token", systemImage: "key")
                        }

                        DisclosureGroup(isExpanded: $vm.showKiteTokenForm) {
                            SecureField("Kite access token", text: $vm.kiteTokenInput)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Button {
                                Task { await vm.saveKiteToken(appState: appState) }
                            } label: {
                                HStack {
                                    Spacer()
                                    if vm.isSavingKiteToken {
                                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                                    } else {
                                        Text("Save Kite Token")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(vm.isSavingKiteToken || vm.kiteTokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        } label: {
                            Label("Paste Kite Token", systemImage: "key")
                        }

                        if let success = vm.tokenSaveSuccess {
                            Label(success, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        if let err = vm.tokenSaveError {
                            Label(err, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Broker Auth")
                    }
                } else {
                    // Loading / disconnected placeholder
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView()
                                Text(appState.connectionState == .disconnected ? "Retrying connection…" : "Connecting to server…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Auto Trader")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .refreshable { await appState.fetchStatus() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $vm.showFyersAuth) {
                if let url = vm.fyersAuthURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                        .onDisappear {
                            Task { await vm.handleFyersAuthDismiss(appState: appState) }
                        }
                }
            }
            .alert(vm.alertMessage ?? "", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                elapsed = elapsedIfRunning()
                appState.startPolling()
            }
            .onDisappear { appState.stopPolling() }
            .onReceive(timer) { _ in elapsed = elapsedIfRunning() }
        }
    }

    @ViewBuilder
    private func tokenStatusRow(broker: String, label: String) -> some View {
        let tokens = status?.tokens ?? [:]
        let val = tokens[broker] ?? "not set"
        let isReady = val.contains("updated") || val.contains("loaded")
        LabeledContent(label) {
            HStack(spacing: 4) {
                if isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                Text(val.isEmpty ? "not set" : val)
                    .foregroundStyle(isReady ? Color.green : Color.gray)
            }
        }
    }

    private func elapsedIfRunning() -> String {
        guard let s = status, s.running, let startedAt = s.startedAt else { return "" }
        return elapsedString(since: startedAt)
    }

    private func formattedStartTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "HH:mm:ss"
        return out.string(from: date)
    }

    private func elapsedString(since iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let start = f.date(from: iso) else { return "" }
        let secs = Int(-start.timeIntervalSinceNow)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        return String(format: "%dm %02ds", m, s)
    }
}
