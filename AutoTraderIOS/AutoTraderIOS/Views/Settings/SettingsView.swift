import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsVM()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Form {
                    Section("Server") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Base URL")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            TextField("http://100.91.5.110:8000", text: $appState.serverBaseURL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.cardBg)

                    Section {
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            Task { await vm.testConnection(client: appState.client) }
                        } label: {
                            HStack {
                                Text("Test Connection")
                                    .foregroundColor(Theme.blue)
                                Spacer()
                                testResultView
                            }
                        }
                    }
                    .listRowBackground(Theme.cardBg)

                    Section("About") {
                        HStack {
                            Text("Version")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(Theme.textPrimary)
                        }
                        Text("Access requires Tailscale to be connected to your Windows machine.")
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.cardBg)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.blue)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var testResultView: some View {
        switch vm.testResult {
        case .none:
            EmptyView()
        case .testing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.green)
        case .failure(let msg):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.red)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(Theme.red)
                    .lineLimit(2)
            }
        }
    }
}
