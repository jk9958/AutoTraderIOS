import SwiftUI

struct SettingsView: View {
    @ObservedObject var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL: String = ""
    @State private var isTesting: Bool = false
    @State private var connectionStatus: ConnectionStatus? = nil

    enum ConnectionStatus {
        case success
        case failure(String)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    // Server section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server Base URL")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Theme.textSecondary)
                            TextField("http://100.124.30.59:8000", text: $baseURL)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Theme.text)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .listRowBackground(Theme.card)

                        Button {
                            applyURL()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.green)
                                Text("Save URL")
                                    .foregroundColor(Theme.green)
                            }
                        }
                        .listRowBackground(Theme.card)

                        // Test connection
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task { await testConnection() }
                            } label: {
                                HStack {
                                    if isTesting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "network")
                                            .foregroundColor(Theme.blue)
                                    }
                                    Text("Test Connection")
                                        .foregroundColor(Theme.blue)
                                    Spacer()
                                }
                            }
                            .disabled(isTesting)

                            if let status = connectionStatus {
                                switch status {
                                case .success:
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.green)
                                            .font(.caption)
                                        Text("Connected successfully!")
                                            .font(.caption)
                                            .foregroundColor(Theme.green)
                                    }
                                case .failure(let msg):
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.red)
                                            .font(.caption)
                                        Text(msg)
                                            .font(.caption)
                                            .foregroundColor(Theme.red)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Theme.card)

                    } header: {
                        Text("Server")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Network note
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Theme.blue)
                                .font(.title3)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tailscale Required")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.text)
                                Text("This app communicates with your Windows machine over Tailscale. Make sure Tailscale is connected before using the app.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .listRowBackground(Theme.card)
                    } header: {
                        Text("Network")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // About section
                    Section {
                        HStack {
                            Text("App Version")
                                .foregroundColor(Theme.text)
                            Spacer()
                            Text("\(appVersion) (\(buildNumber))")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .listRowBackground(Theme.card)
                    } header: {
                        Text("About")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            baseURL = apiClient.baseURL
        }
    }

    private func applyURL() {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        apiClient.baseURL = trimmed
        connectionStatus = nil
    }

    private func testConnection() async {
        applyURL()
        isTesting = true
        connectionStatus = nil
        defer { isTesting = false }
        do {
            try await apiClient.checkHealth()
            connectionStatus = .success
        } catch let error as APIError {
            connectionStatus = .failure(error.errorDescription ?? "Connection failed.")
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
    }
}
