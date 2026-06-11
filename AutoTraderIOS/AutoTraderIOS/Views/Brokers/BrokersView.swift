import SwiftUI

struct BrokersView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = BrokersVM()

    var body: some View {
        NavigationStack {
            List {
                if let err = vm.loadError {
                    Section { Text(err).font(.caption).foregroundStyle(.red) }
                }
                if let msg = vm.saveSuccess {
                    Section { Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline) }
                }
                if let err = vm.saveError {
                    Section { Text(err).font(.caption).foregroundStyle(.red) }
                }

                // Fyers
                BrokerCard(name: "Fyers", status: vm.status(for: "fyers")) {
                    Button {
                        vm.openFyersAuth(appState: appState)
                    } label: {
                        Label("Login with Fyers", systemImage: "person.badge.key")
                    }
                    TokenPasteField(
                        placeholder: "Paste Fyers access token",
                        text: $vm.fyersTokenInput,
                        isSaving: vm.savingBroker == "fyers",
                        onSave: { Task { await vm.saveFyersToken(appState: appState) } }
                    )
                }

                // Kite
                BrokerCard(name: "Kite", status: vm.status(for: "kite")) {
                    TokenPasteField(
                        placeholder: "Paste Kite access token",
                        text: $vm.kiteTokenInput,
                        isSaving: vm.savingBroker == "kite",
                        onSave: { Task { await vm.saveKiteToken(appState: appState) } }
                    )
                }

                // Tradesmart
                BrokerCard(name: "Tradesmart", status: vm.status(for: "tradesmart")) {
                    TokenPasteField(
                        placeholder: "Paste Tradesmart auth code",
                        text: $vm.tradesmartCodeInput,
                        isSaving: vm.savingBroker == "tradesmart",
                        onSave: { Task { await vm.exchangeTradesmart(appState: appState) } }
                    )
                }
            }
            .navigationTitle("Brokers")
            .refreshable { await vm.reload(appState: appState) }
            .task { await vm.reload(appState: appState) }
            .sheet(isPresented: $vm.showFyersAuth, onDismiss: {
                Task { await vm.handleFyersAuthDismiss(appState: appState) }
            }) {
                if let url = vm.fyersAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
        }
    }
}

private struct BrokerCard<Content: View>: View {
    let name: String
    let status: BrokerStatus?
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            content
        } header: {
            HStack {
                Text(name)
                Spacer()
                statusPill
            }
        } footer: {
            if let preview = status?.tokenPreview, !preview.isEmpty {
                Text("Token: \(preview)")
            } else if status?.isValid == false {
                Text("No valid token.")
            }
        }
    }

    private var statusPill: some View {
        let valid = status?.isValid ?? false
        let label = status == nil ? "UNKNOWN" : (valid ? "VALID" : "EXPIRED")
        let color: Color = status == nil ? Theme.textSecondary : (valid ? Theme.green : Theme.red)
        return Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct TokenPasteField: View {
    let placeholder: String
    @Binding var text: String
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.callout, design: .monospaced))
            Button {
                onSave()
            } label: {
                if isSaving { ProgressView() } else { Text("Save") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
