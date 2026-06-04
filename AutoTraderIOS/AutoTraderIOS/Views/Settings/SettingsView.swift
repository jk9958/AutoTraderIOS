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
            SecureField("Admin access code", text: $apiKeyDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitAPIKey() }
            if appState.hasAPIKey {
                Button {
                    newKeyInput = ""
                    vm.rotateMessage = nil
                    showRotate = true
                } label: {
                    Label("Rotate Key on Server", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } header: {
            Text("API Key")
        } footer: {
            Text("Required for engine create/start/stop/delete (mobile API v1). Stored in the device Keychain, sent as the X-API-Key header.")
        }
        .sheet(isPresented: $showRotate) { rotateSheet }
    }

    private var rotateSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New API key (≥ 12 chars)", text: $newKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Authenticates with the current key, then sets the new one. The new key takes effect immediately and is saved on this device.")
                }
                if let msg = vm.rotateMessage {
                    Section {
                        Label(msg, systemImage: vm.rotateFailed ? "xmark.circle" : "checkmark.circle")
                            .foregroundStyle(vm.rotateFailed ? .red : .green)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Rotate API Key")
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
