import SwiftUI
import AuthenticationServices

struct TokenCard: View {
    let status: ServerStatus
    @ObservedObject var viewModel: DashboardViewModel
    let apiClient: APIClient
    @State private var expandedBroker: String? = nil
    @State private var fyersManualToken: String = ""
    @State private var kiteManualToken: String = ""
    @State private var isSavingFyers: Bool = false
    @State private var isSavingKite: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Auth Tokens")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(Theme.divider)

            // Token badges
            HStack(spacing: 12) {
                TokenBadge(
                    broker: "Fyers",
                    value: status.tokens["fyers"] ?? "not set",
                    tokenStatus: status.tokenStatus(for: "fyers")
                )
                TokenBadge(
                    broker: "Kite",
                    value: status.tokens["kite"] ?? "not set",
                    tokenStatus: status.tokenStatus(for: "kite")
                )
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Theme.divider)

            // Fyers OAuth button
            FyersLoginButton(viewModel: viewModel, apiClient: apiClient)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Manual token sections
            ManualTokenSection(
                broker: "fyers",
                displayName: "Fyers",
                token: $fyersManualToken,
                isExpanded: Binding(
                    get: { expandedBroker == "fyers" },
                    set: { expanded in expandedBroker = expanded ? "fyers" : nil }
                ),
                isSaving: isSavingFyers
            ) {
                Task {
                    isSavingFyers = true
                    await viewModel.saveToken(broker: "fyers", token: fyersManualToken, using: apiClient)
                    isSavingFyers = false
                    fyersManualToken = ""
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ManualTokenSection(
                broker: "kite",
                displayName: "Kite",
                token: $kiteManualToken,
                isExpanded: Binding(
                    get: { expandedBroker == "kite" },
                    set: { expanded in expandedBroker = expanded ? "kite" : nil }
                ),
                isSaving: isSavingKite
            ) {
                Task {
                    isSavingKite = true
                    await viewModel.saveToken(broker: "kite", token: kiteManualToken, using: apiClient)
                    isSavingKite = false
                    kiteManualToken = ""
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

private struct TokenBadge: View {
    let broker: String
    let value: String
    let tokenStatus: TokenStatus

    var badgeColor: Color {
        switch tokenStatus {
        case .ok:     return Theme.green
        case .stale:  return Theme.orange
        case .notSet: return Color(hex: "555558")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)
                Text(broker)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.text)
            }
            Text(value)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(badgeColor.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct FyersLoginButton: View {
    @ObservedObject var viewModel: DashboardViewModel
    let apiClient: APIClient

    var body: some View {
        Button {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                viewModel.loginWithFyers(presentationAnchor: window, apiClient: apiClient)
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isFyersLoginLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "safari")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Login with Fyers")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Theme.blue)
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(viewModel.isFyersLoginLoading)
    }
}

private struct ManualTokenSection: View {
    let broker: String
    let displayName: String
    @Binding var token: String
    @Binding var isExpanded: Bool
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Paste \(displayName) token manually")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 8)
            }

            if isExpanded {
                VStack(spacing: 8) {
                    SecureField("Paste \(displayName) access token here", text: $token)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .padding(10)
                        .background(Theme.background)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )

                    LoadingButton(
                        title: "Save \(displayName) Token",
                        icon: "checkmark",
                        color: Theme.green,
                        isLoading: isSaving,
                        isDisabled: token.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        onSave()
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}
