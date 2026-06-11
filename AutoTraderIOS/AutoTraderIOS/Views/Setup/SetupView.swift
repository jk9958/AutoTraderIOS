import SwiftUI

/// Shown when no API key is configured. Since the server's login gate now 401s
/// every endpoint without a valid `X-API-Key`, the app is unusable without one —
/// so we block the tabs behind this setup step instead of letting every screen
/// fail with a buried error. The user can still continue without a key for an
/// unauthenticated server.
struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @Binding var skipKeyGate: Bool

    @StateObject private var vm = SettingsVM()
    @State private var keyDraft = ""
    @State private var revealKey = false

    private var trimmedKey: String {
        keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        Text("This server requires an API key. Add it below to use the app.")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Theme.blue)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Sign in")
                }

                Section {
                    TextField("https://trader.allweatheralgo.com", text: $appState.serverBaseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Server URL")
                }

                Section {
                    HStack {
                        if revealKey {
                            TextField("X-API-Key", text: $keyDraft)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("X-API-Key", text: $keyDraft)
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

                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Task { await testDraft() }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "wifi.badge.checkmark.fill")
                            Spacer()
                            testResultView
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Stored securely in the Keychain. Find it on the dashboard under Settings.")
                }

                Section {
                    Button {
                        commitKey()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save & Continue")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(trimmedKey.isEmpty)
                }

                Section {
                    Button("Continue without a key") {
                        skipKeyGate = true
                    }
                    .foregroundStyle(.secondary)
                } footer: {
                    Text("Only for an unauthenticated server. Most screens will fail with 401 if the server requires a key.")
                }
            }
            .navigationTitle("Auto Trader")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func commitKey() {
        appState.apiKey = trimmedKey   // flips `hasAPIKey`, dismissing this gate
    }

    private func testDraft() async {
        var client = APIClient(baseURL: appState.serverBaseURL)
        client.apiKey = trimmedKey
        await vm.testConnection(client: client, hasAPIKey: !trimmedKey.isEmpty)
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
