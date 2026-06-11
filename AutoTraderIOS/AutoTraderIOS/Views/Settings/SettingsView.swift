import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsVM()
    @Environment(\.dismiss) private var dismiss
    @State private var revealKey = false

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

                Section {
                    HStack {
                        if revealKey {
                            TextField("X-API-Key", text: $appState.apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("X-API-Key", text: $appState.apiKey)
                                .textContentType(.password)
                        }
                        Button {
                            revealKey.toggle()
                        } label: {
                            Image(systemName: revealKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    LabeledContent("Status") {
                        Text(appState.hasAPIKey ? appState.maskedAPIKey : "Not set")
                            .foregroundStyle(appState.hasAPIKey ? Color.secondary : Color.orange)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    NavigationLink {
                        RotateKeyView()
                    } label: {
                        Label("Rotate API Key", systemImage: "key.horizontal")
                    }
                    .disabled(!appState.hasAPIKey)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Required for engine launch, stop, and other write actions. Stored securely in the Keychain.")
                }

                Section {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Task { await vm.testConnection(client: appState.client, hasAPIKey: appState.hasAPIKey) }
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
                    Button("Done") { dismiss() }
                }
            }
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
