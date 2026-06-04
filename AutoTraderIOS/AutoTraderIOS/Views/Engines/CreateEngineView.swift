import SwiftUI

/// Create-engine form (POST /api/v1/engines). Writes config YAML + secrets and
/// optionally autostarts. Mirrors server validation: engine_id regex, broker &
/// strategy enums.
struct CreateEngineView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CreateEngineVM()

    /// Called after a successful create so the caller can refresh its list.
    var onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("engine_fyers_01", text: $vm.engineId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Engine ID")
                } footer: {
                    if vm.engineId.isEmpty {
                        Text("Letters, digits, underscore, hyphen only.")
                    } else if !vm.idIsValid {
                        Text("Invalid — use only letters, digits, underscore, hyphen.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Broker & Strategy") {
                    Picker("Broker", selection: $vm.broker) {
                        ForEach(EngineBroker.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Strategy", selection: $vm.strategy) {
                        ForEach(EngineStrategy.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Dry run (paper)", isOn: $vm.dryRun)
                }

                Section {
                    SecureField("Broker access token", text: $vm.accessToken)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Secrets (optional)")
                } footer: {
                    Text("Stored server-side in the engine's secrets file (chmod 600).")
                }

                Section("Telegram (optional)") {
                    TextField("Bot token", text: $vm.telegramBotToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Chat ID", text: $vm.telegramChatId)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                }

                Section {
                    Toggle(isOn: $vm.autostart) {
                        Label("Start immediately", systemImage: "bolt.fill")
                    }
                } footer: {
                    if vm.autostart && !vm.dryRun {
                        Text("⚠️ This will start a LIVE engine right after creation.")
                            .foregroundStyle(.orange)
                    }
                }

                if let banner = vm.banner {
                    Section {
                        Label(banner, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("New Engine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await vm.submit(client: appState.client) {
                                onCreated()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!vm.canSubmit)
                }
            }
            .overlay {
                if vm.isSubmitting {
                    ProgressView("Creating…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
