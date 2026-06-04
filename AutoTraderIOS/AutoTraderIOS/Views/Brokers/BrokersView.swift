import SwiftUI

/// Friendly broker connection screen. One tap to connect each broker via the
/// secure web login (OAuth); clear Connected / Reconnect status. Replaces routing
/// novices to the engineer dashboard.
struct BrokersView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardVM()
    @Environment(\.dismiss) private var dismiss

    private struct Broker: Identifiable {
        let id: String
        let name: String
        let tint: Color
    }
    private let brokers: [Broker] = [
        .init(id: "fyers", name: "Fyers", tint: .blue),
        .init(id: "kite", name: "Zerodha (Kite)", tint: .purple),
        .init(id: "tradesmart", name: "TradeSmart", tint: .indigo),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(brokers) { broker in
                        row(broker)
                    }
                } header: {
                    Text("Your trading accounts")
                } footer: {
                    Text("A broker is the account that actually places trades. Logins expire at the end of each day, so you'll reconnect from time to time. You don't need a broker to use Practice mode.")
                }
            }
            .navigationTitle("Brokers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await appState.fetchStatus() }
            .sheet(isPresented: $vm.showFyersAuth) {
                if let url = vm.fyersAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleFyersAuthDismiss(appState: appState); noteIfConnected("fyers") } }
                }
            }
            .sheet(isPresented: $vm.showKiteAuth) {
                if let url = vm.kiteAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleKiteAuthDismiss(appState: appState); noteIfConnected("kite") } }
                }
            }
            .sheet(isPresented: $vm.showTradesmartAuth) {
                if let url = vm.tradesmartAuthURL {
                    SafariView(url: url).ignoresSafeArea()
                        .onDisappear { Task { await vm.handleTradesmartAuthDismiss(appState: appState); noteIfConnected("tradesmart") } }
                }
            }
            .alert(vm.alertMessage ?? "", isPresented: $vm.showAlert) { Button("OK", role: .cancel) {} }
        }
    }

    @ViewBuilder
    private func row(_ broker: Broker) -> some View {
        let connected = isConnected(broker.id)
        HStack(spacing: 14) {
            Image(systemName: "building.columns.fill")
                .foregroundStyle(broker.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(broker.name).font(.headline)
                StatusChip(status: connected ? .connected : .disconnected, compact: true)
            }
            Spacer()
            Button(connected ? "Reconnect" : "Connect") { connect(broker.id) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(connected ? .secondary : .blue)
        }
        .padding(.vertical, 4)
    }

    private func isConnected(_ id: String) -> Bool {
        let v = appState.serverStatus?.tokens?[id] ?? ""
        return v.contains("updated") || v.contains("loaded") || v.contains("active")
    }

    private func connect(_ id: String) {
        switch id {
        case "fyers":      vm.openFyersAuth(appState: appState)
        case "kite":       vm.openKiteAuth(appState: appState)
        case "tradesmart": vm.openTradesmartAuth(appState: appState)
        default: break
        }
    }

    private func noteIfConnected(_ id: String) {
        if isConnected(id) { Analytics.shared.track(.brokerConnected(broker: id)) }
    }
}
