import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsVM()
    @Environment(\.dismiss) private var dismiss

    @State private var showRotate = false
    @State private var newKeyInput = ""
    /// Local draft so we don't write the Keychain + rebuild the client on every
    /// keystroke; committed on submit / Done / dismiss.
    @State private var apiKeyDraft = ""
    @State private var revealKey = false

    private func commitAPIKey() {
        if apiKeyDraft != appState.apiKey { appState.apiKey = apiKeyDraft }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://trader.allweatheralgo.com", text: $appState.serverBaseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Server URL")
                } footer: {
                    Text("Base URL for the trading API server.")
                }

                apiKeySection

                Section {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Task { await vm.testConnection(client: appState.client) }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "wifi.badge.checkmark.fill")
                            Spacer()
                            testResultView
                        }
                    }
                } header: {
                    Text("Diagnostics")
                }

                Section {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Server") {
                        Text("trader.allweatheralgo.com")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitAPIKey(); dismiss() }
                }
            }
            .onAppear { apiKeyDraft = appState.apiKey }
            .onDisappear { commitAPIKey() }   // safety net if dismissed by swipe
        }
    }

    // MARK: - API Key (mobile write key)

    @ViewBuilder
    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if revealKey {
                        TextField("Admin access code", text: $apiKeyDraft)
                    } else {
                        SecureField("Admin access code", text: $apiKeyDraft)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitAPIKey() }

                Button { revealKey.toggle() } label: {
                    Image(systemName: revealKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(revealKey ? "Hide access code" : "Show access code")
            }

            // Clear status so a saved (masked) code doesn't look missing.
            HStack(spacing: 6) {
                Image(systemName: keyStatus.icon).foregroundStyle(keyStatus.color)
                Text(keyStatus.text).foregroundStyle(.secondary)
            }
            .font(.caption)

            if appState.hasAPIKey {
                Button {
                    newKeyInput = ""
                    vm.rotateMessage = nil
                    showRotate = true
                } label: {
                    Label("Change access code on server", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } header: {
            Text("Access code")
        } footer: {
            Text("This code lets the app create and control your bots. Whoever set up your server gives it to you. It's stored securely on this device only — tap the eye to check it.")
        }
        .sheet(isPresented: $showRotate) { rotateSheet }
    }

    private var keyStatus: (icon: String, color: Color, text: String) {
        if appState.hasAPIKey && apiKeyDraft == appState.apiKey {
            return ("checkmark.circle.fill", .green, "Access code saved on this device")
        } else if !apiKeyDraft.isEmpty {
            return ("pencil.circle.fill", .orange, "Tap Done to save this code")
        } else {
            return ("exclamationmark.circle", .orange, "No access code yet — paste the one your provider gave you")
        }
    }

    private var rotateSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New access code (≥ 12 characters)", text: $newKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Checks your current code, then sets the new one. It takes effect immediately and is saved on this device.")
                }
                if let msg = vm.rotateMessage {
                    Section {
                        Label(msg, systemImage: vm.rotateFailed ? "xmark.circle" : "checkmark.circle")
                            .foregroundStyle(vm.rotateFailed ? .red : .green)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Change access code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showRotate = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rotate") {
                        Task {
                            if let newKey = await vm.rotateKey(newKey: newKeyInput, client: appState.client) {
                                appState.apiKey = newKey   // persists to Keychain + rebuilds client
                                apiKeyDraft = newKey        // keep the field in sync
                                try? await Task.sleep(for: .seconds(1))
                                showRotate = false
                            }
                        }
                    }
                    .disabled(vm.isRotating || !EngineValidation.isValidApiKey(newKeyInput))
                }
            }
            .overlay {
                if vm.isRotating { ProgressView().padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var testResultView: some View {
        switch vm.testResult {
        case .none:
            EmptyView()
        case .testing:
            ProgressView().progressViewStyle(.circular)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let msg):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }
}
