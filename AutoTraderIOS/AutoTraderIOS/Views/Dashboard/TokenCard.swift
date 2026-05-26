import SwiftUI
import SafariServices

struct TokenCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: DashboardVM

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AUTH TOKENS")
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                    .tracking(0.5)
                Text("Broker Authentication")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            VStack(spacing: 10) {
                brokerBadge(broker: "fyers", label: "Fyers")
                brokerBadge(broker: "kite", label: "Kite")
            }

            Divider().background(Color.white.opacity(0.1))

            LoadingButton("Login with Fyers", color: Theme.blue) {
                vm.openFyersAuth(appState: appState)
            }

            DisclosureGroup(
                isExpanded: $vm.showFyersTokenForm,
                content: {
                    VStack(spacing: 8) {
                        SecureField("Fyers access token", text: $vm.fyersTokenInput)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(Theme.glassAccent)
                            .cornerRadius(8)
                        LoadingButton("Save Token", isLoading: vm.isSavingFyersToken, color: Theme.green) {
                            Task { await vm.saveFyersToken(appState: appState) }
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Theme.blue)
                        Text("Paste Fyers token manually")
                            .font(.subheadline)
                            .foregroundColor(Theme.blue)
                        Spacer()
                    }
                }
            )

            DisclosureGroup(
                isExpanded: $vm.showKiteTokenForm,
                content: {
                    VStack(spacing: 8) {
                        SecureField("Kite access token", text: $vm.kiteTokenInput)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(Theme.glassAccent)
                            .cornerRadius(8)
                        LoadingButton("Save Token", isLoading: vm.isSavingKiteToken, color: Theme.green) {
                            Task { await vm.saveKiteToken(appState: appState) }
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Theme.blue)
                        Text("Paste Kite token manually")
                            .font(.subheadline)
                            .foregroundColor(Theme.blue)
                        Spacer()
                    }
                }
            )

            if let success = vm.tokenSaveSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.green)
                    Text(success)
                        .font(.caption)
                        .foregroundColor(Theme.green)
                }
                .padding(10)
                .background(Theme.green.opacity(0.15))
                .cornerRadius(8)
            }
            if let err = vm.tokenSaveError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(Theme.red)
                }
                .padding(10)
                .background(Theme.red.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .glassStyle()
        .sheet(isPresented: $vm.showFyersAuth) {
            if let url = vm.fyersAuthURL {
                SafariView(url: url)
                    .ignoresSafeArea()
                    .onDisappear {
                        Task { await vm.handleFyersAuthDismiss(appState: appState) }
                    }
            }
        }
    }

    private func brokerBadge(broker: String, label: String) -> some View {
        let tokens = appState.serverStatus?.tokens ?? [:]
        let val = tokens[broker] ?? "not set"
        let color: Color = {
            if val.contains("updated") || val.contains("loaded") { return Theme.green }
            if val == "not set" || val.isEmpty { return Theme.textSecondary }
            return Theme.orange
        }()
        let isReady = val.contains("updated") || val.contains("loaded")

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                Text(val.isEmpty ? "not set" : val)
                    .font(.caption2.bold())
                    .foregroundColor(color)
                    .lineLimit(1)
            }
            Spacer()
            if isReady {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .padding(10)
        .background(color.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Safari wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
