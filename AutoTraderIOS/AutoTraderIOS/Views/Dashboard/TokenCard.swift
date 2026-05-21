import SwiftUI
import SafariServices

struct TokenCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: DashboardVM

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Auth Tokens")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 16) {
                brokerBadge(broker: "fyers", label: "Fyers")
                brokerBadge(broker: "kite", label: "Kite")
                Spacer()
            }

            // Fyers OAuth
            LoadingButton("Login with Fyers", color: Theme.blue) {
                vm.openFyersAuth(appState: appState)
            }

            // Manual token forms
            DisclosureGroup(
                isExpanded: $vm.showFyersTokenForm,
                content: {
                    HStack {
                        SecureField("Fyers access token", text: $vm.fyersTokenInput)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        LoadingButton("Save", isLoading: vm.isSavingFyersToken, color: Theme.green) {
                            Task { await vm.saveFyersToken(appState: appState) }
                        }
                        .frame(width: 70)
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text("Paste Fyers token manually")
                        .font(.subheadline)
                        .foregroundColor(Theme.blue)
                }
            )

            DisclosureGroup(
                isExpanded: $vm.showKiteTokenForm,
                content: {
                    HStack {
                        SecureField("Kite access token", text: $vm.kiteTokenInput)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        LoadingButton("Save", isLoading: vm.isSavingKiteToken, color: Theme.green) {
                            Task { await vm.saveKiteToken(appState: appState) }
                        }
                        .frame(width: 70)
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text("Paste Kite token manually")
                        .font(.subheadline)
                        .foregroundColor(Theme.blue)
                }
            )

            if let success = vm.tokenSaveSuccess {
                Text(success)
                    .font(.caption)
                    .foregroundColor(Theme.green)
            }
            if let err = vm.tokenSaveError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(Theme.red)
            }
        }
        .cardStyle()
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
        return VStack(spacing: 4) {
            Text(label).font(.caption.bold()).foregroundColor(Theme.textSecondary)
            Text(val.isEmpty ? "not set" : val)
                .font(.caption2)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
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
