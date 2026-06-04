import SwiftUI

struct TradeView: View {
    @EnvironmentObject var apiClient: APIClient
    @StateObject private var viewModel = TradeViewModel()
    @State private var expandedSection: String? = "ironCondor"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {

                        // Success banner
                        if viewModel.showSuccessBanner {
                            Banner(
                                message: viewModel.successMessage,
                                style: .success,
                                onDismiss: { viewModel.showSuccessBanner = false }
                            )
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Iron Condor section
                        CollapsibleSection(
                            title: "Iron Condor",
                            icon: "chart.bar.fill",
                            isExpanded: Binding(
                                get: { expandedSection == "ironCondor" },
                                set: { isExpanded in expandedSection = isExpanded ? "ironCondor" : nil }
                            )
                        ) {
                            IronCondorForm(
                                params: $viewModel.ironCondorParams,
                                validationErrors: viewModel.validationErrors,
                                isRunning: viewModel.engineIsRunning,
                                isLaunching: viewModel.isLaunchingIronCondor,
                                onLaunch: { viewModel.requestLaunchIronCondor() }
                            )
                        }
                        .padding(.horizontal, 16)

                        // Scalping section
                        CollapsibleSection(
                            title: "Scalping",
                            icon: "bolt.fill",
                            isExpanded: Binding(
                                get: { expandedSection == "scalping" },
                                set: { isExpanded in expandedSection = isExpanded ? "scalping" : nil }
                            )
                        ) {
                            SimpleEngineForm(
                                engineName: "Scalping",
                                dryRun: $viewModel.scalpingDryRun,
                                isRunning: viewModel.engineIsRunning,
                                isLaunching: viewModel.isLaunchingScalping,
                                onLaunch: { viewModel.requestLaunchScalping() }
                            )
                        }
                        .padding(.horizontal, 16)

                        // Options section
                        CollapsibleSection(
                            title: "Options",
                            icon: "arrow.up.arrow.down",
                            isExpanded: Binding(
                                get: { expandedSection == "options" },
                                set: { isExpanded in expandedSection = isExpanded ? "options" : nil }
                            )
                        ) {
                            SimpleEngineForm(
                                engineName: "Options",
                                dryRun: $viewModel.optionsDryRun,
                                isRunning: viewModel.engineIsRunning,
                                isLaunching: viewModel.isLaunchingOptions,
                                onLaunch: { viewModel.requestLaunchOptions() }
                            )
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 8)
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.showSuccessBanner)
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.apiClient = apiClient
        }
        // Iron Condor LIVE confirmation
        .confirmationDialog(
            "Launch in LIVE mode?",
            isPresented: $viewModel.showLiveConfirmationIronCondor,
            titleVisibility: .visible
        ) {
            Button("Launch LIVE", role: .destructive) {
                Task { await viewModel.launchIronCondor() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LIVE mode — real orders will be placed with real money. Are you sure?")
        }
        // Scalping LIVE confirmation
        .confirmationDialog(
            "Launch in LIVE mode?",
            isPresented: $viewModel.showLiveConfirmationScalping,
            titleVisibility: .visible
        ) {
            Button("Launch LIVE", role: .destructive) {
                Task { await viewModel.launchScalping() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LIVE mode — real orders will be placed with real money. Are you sure?")
        }
        // Options LIVE confirmation
        .confirmationDialog(
            "Launch in LIVE mode?",
            isPresented: $viewModel.showLiveConfirmationOptions,
            titleVisibility: .visible
        ) {
            Button("Launch LIVE", role: .destructive) {
                Task { await viewModel.launchOptions() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LIVE mode — real orders will be placed with real money. Are you sure?")
        }
        // Conflict alert (409)
        .alert("Engine Already Running", isPresented: $viewModel.showConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.conflictMessage)
        }
        // Generic error alert
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

private struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.blue)
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(16)
            }

            if isExpanded {
                Divider().background(Theme.divider)
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .padding(16)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

private struct SimpleEngineForm: View {
    let engineName: String
    @Binding var dryRun: Bool
    let isRunning: Bool
    let isLaunching: Bool
    let onLaunch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dry run")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.text)
                    Text(dryRun ? "Simulation mode" : "LIVE — real orders!")
                        .font(.caption)
                        .foregroundColor(dryRun ? Theme.textSecondary : Theme.red)
                }
                Spacer()
                Toggle("", isOn: $dryRun)
                    .tint(Theme.green)
                    .labelsHidden()
            }

            if isRunning {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.orange)
                    Text("Stop the current engine first.")
                        .font(.subheadline)
                        .foregroundColor(Theme.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.orange.opacity(0.15))
                .cornerRadius(Theme.cornerRadius)
            } else {
                LoadingButton(
                    title: "Launch \(engineName)",
                    icon: "play.fill",
                    color: dryRun ? Theme.green : Theme.red,
                    isLoading: isLaunching
                ) {
                    onLaunch()
                }
            }
        }
    }
}
