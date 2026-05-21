import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardVM()
    @State private var showSettings = false
    @State private var showBanner = true

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
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
                        HStack {
                            Spacer()
                            Text(status.isPaperTrading ? "PAPER TRADING" : "⚡ LIVE TRADING ⚡")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(status.isPaperTrading ? Theme.orange : Theme.red)
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
                                ProgressView(appState.connectionState == .disconnected ? "Retrying…" : "Connecting…")
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.top, 40)
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
