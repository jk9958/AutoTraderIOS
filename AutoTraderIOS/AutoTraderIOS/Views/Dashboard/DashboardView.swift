import SwiftUI
import Combine

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
                        HStack(spacing: 8) {
                            Image(systemName: status.isPaperTrading ? "book.fill" : "bolt.fill")
                                .font(.caption.bold())
                            Text(status.isPaperTrading ? "PAPER TRADING" : "LIVE TRADING")
                                .font(.caption.bold().tracking(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    (status.isPaperTrading ? Theme.orange : Theme.red).opacity(0.8),
                                    (status.isPaperTrading ? Theme.orange : Theme.red).opacity(0.6)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(Theme.blue)
                                    Text(appState.connectionState == .disconnected ? "Retrying connection…" : "Connecting to server…")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.top, 60)
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
