import SwiftUI
import Combine

private struct TradingModeBanner: View {
    let isPaper: Bool

    var body: some View {
        let leading = (isPaper ? Theme.orange : Theme.red).opacity(0.8)
        let trailing = (isPaper ? Theme.orange : Theme.red).opacity(0.6)
        return HStack(spacing: 8) {
            Image(systemName: isPaper ? "book.fill" : "bolt.fill")
                .font(.caption.bold())
            Text(isPaper ? "PAPER TRADING" : "LIVE TRADING")
                .tracking(0.5)
                .font(.caption.bold())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundColor(.white)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [leading, trailing]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

private struct ConnectingPlaceholder: View {
    let isDisconnected: Bool

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.blue)
            Text(isDisconnected ? "Retrying connection…" : "Connecting to server…")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, 60)
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardVM()
    @State private var showSettings = false
    @State private var showBanner = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Connection banner
                    if appState.connectionState == .disconnected,
                       let err = appState.connectionError,
                       showBanner {
                        ConnectionBanner(
                            message: err,
                            onRetry: { appState.refreshNow() },
                            onDismiss: { showBanner = false }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // LIVE/PAPER banner
                    if let status = appState.serverStatus {
                        TradingModeBanner(isPaper: status.isPaperTrading)
                    }

                    ScrollView {
                        VStack(spacing: 16) {
                            if let status = appState.serverStatus {
                                EngineStatusCard(
                                    status: status,
                                    isStoppingEngine: vm.isStoppingEngine,
                                    stopError: vm.stopError,
                                    onStop: {
                                        Task { await vm.stopEngine(appState: appState) }
                                    }
                                )

                                TokenCard(vm: vm)
                            } else if appState.serverStatus == nil {
                                ConnectingPlaceholder(isDisconnected: appState.connectionState == .disconnected)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await appState.fetchStatus()
                    }
                }
            }
            .navigationTitle("Auto Trader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.headline)
                            .foregroundColor(Theme.blue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(vm.alertMessage ?? "", isPresented: $vm.showAlert) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                showBanner = true
                appState.startPolling()
            }
            .onDisappear {
                appState.stopPolling()
            }
            .onChange(of: appState.connectionState) { _, state in
                if state == .connected { showBanner = false }
                else if state == .disconnected { showBanner = true }
            }
        }
        .preferredColorScheme(.dark)
    }
}

