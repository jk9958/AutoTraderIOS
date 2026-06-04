import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var apiClient: APIClient
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Connection error banner
                        if let error = viewModel.connectionError {
                            Banner(
                                message: error,
                                style: .error,
                                onDismiss: { viewModel.connectionError = nil },
                                actionTitle: "Retry",
                                onAction: { Task { await viewModel.refresh(using: apiClient) } }
                            )
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Main content
                        if let status = viewModel.status {
                            // Engine status card
                            EngineStatusCard(
                                status: status,
                                showStopConfirmation: $viewModel.showStopConfirmation,
                                isStoppingEngine: viewModel.isStoppingEngine
                            )
                            .padding(.horizontal, 16)

                            // Token card
                            TokenCard(status: status, viewModel: viewModel, apiClient: apiClient)
                                .padding(.horizontal, 16)

                            // Quick action
                            QuickActionCard()
                                .padding(.horizontal, 16)

                            Spacer(minLength: 24)
                        } else if !viewModel.hasHadFirstLoad {
                            LoadingPlaceholder()
                        }
                    }
                    .padding(.top, 8)
                }
                .refreshable { await viewModel.refresh(using: apiClient) }
                .animation(.easeInOut(duration: 0.25), value: viewModel.connectionError)

                // Toast overlay
                if let toast = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(24)
                            .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: toast)
                }
            }
            .navigationTitle("Auto Trader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(Theme.blue)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(apiClient: apiClient)
            }
            .confirmationDialog(
                "Stop the running engine?",
                isPresented: $viewModel.showStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Stop Engine", role: .destructive) {
                    Task { await viewModel.stopEngine(using: apiClient) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will terminate the currently running trading engine.")
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                viewModel.startPolling(using: apiClient)
                Task { await viewModel.refresh(using: apiClient) }
            case .background, .inactive:
                viewModel.stopPolling()
            @unknown default:
                break
            }
        }
        .onAppear {
            viewModel.startPolling(using: apiClient)
            if !viewModel.hasHadFirstLoad {
                Task { await viewModel.refresh(using: apiClient) }
            }
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

private struct QuickActionCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start a Trade")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.text)
                Text("Launch Iron Condor, Scalping, or Options engine")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.textSecondary)
                .font(.caption.weight(.semibold))
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

private struct LoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                .scaleEffect(1.2)
            Text("Connecting to server...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
