import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsVM()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Server settings
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SERVER")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(0.5)
                                Text("API Endpoint")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Base URL")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(0.3)
                                TextField("http://100.91.5.110:8000", text: $appState.serverBaseURL)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(10)
                                    .background(Theme.glassAccent)
                                    .cornerRadius(8)
                            }
                        }
                        .glassStyle()

                        // Connection test
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DIAGNOSTICS")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(0.5)
                                Text("Server Status")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }

                            Button {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                Task { await vm.testConnection(client: appState.client) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "wifi.badge.checkmark.fill")
                                        .font(.headline)
                                        .foregroundColor(Theme.blue)
                                    Text("Test Connection")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    testResultView
                                }
                                .padding(12)
                                .background(Theme.glassAccent)
                                .cornerRadius(10)
                            }
                        }
                        .glassStyle()

                        // About
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ABOUT")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(0.5)
                                Text("App Information")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gear")
                                            .font(.caption.bold())
                                            .foregroundColor(Theme.blue)
                                        Text("Version")
                                    }
                                    .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .padding(10)
                                .background(Theme.glassAccent)
                                .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "network")
                                            .font(.caption.bold())
                                            .foregroundColor(Theme.green)
                                        Text("Network")
                                    }
                                    .foregroundColor(Theme.textSecondary)
                                    .font(.caption.bold())

                                    Text("Access requires Tailscale to be connected to your Windows machine.")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(3)
                                }
                                .padding(10)
                                .background(Theme.glassAccent)
                                .cornerRadius(8)
                            }
                        }
                        .glassStyle()

                        Spacer().frame(height: 20)
                    }
                    .padding(16)
                }
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
