import SwiftUI

struct TradeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TradeVM()

    @State private var expandIC = true
    @State private var expandScalping = false
    @State private var expandOptions = false

    private var engineRunning: Bool { appState.serverStatus?.running ?? false }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // Iron Condor
                        section(title: "Iron Condor", isExpanded: $expandIC) {
                            IronCondorForm(vm: vm)
                        }

                        // Scalping
                        section(title: "Scalping", isExpanded: $expandScalping) {
                            simpleEngine(
                                dryRun: $vm.scalpingDryRun,
                                isLoading: vm.isLaunching,
                                onLaunch: { vm.launchScalping(appState: appState) }
                            )
                        }

                        // Options
                        section(title: "Options", isExpanded: $expandOptions) {
                            simpleEngine(
                                dryRun: $vm.optionsDryRun,
                                isLoading: vm.isLaunching,
                                onLaunch: { vm.launchOptions(appState: appState) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if let status = appState.serverStatus {
                    vm.prefill(nextExpiry: status.nextExpiry)
                }
            }
            .onChange(of: appState.serverStatus?.nextExpiry) { _, expiry in
                if let expiry { vm.prefill(nextExpiry: expiry) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                        .foregroundColor(Theme.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(Theme.textSecondary)
                            .tracking(0.5)
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.blue)
                        .font(.caption.bold())
                }
                .padding(Theme.pad)
                .background(
                    ZStack {
                        Theme.glassBg
                        RoundedRectangle(cornerRadius: isExpanded.wrappedValue ? 0 : Theme.radius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                )
                .cornerRadius(isExpanded.wrappedValue ? 0 : Theme.radius, corners: [.topLeft, .topRight])
                .cornerRadius(isExpanded.wrappedValue ? 0 : Theme.radius)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))
                    content()
                        .padding(Theme.pad)
                }
                .background(Theme.glassBg)
                .cornerRadius(Theme.radius, corners: [.bottomLeft, .bottomRight])
            }
        }
    }

    private func simpleEngine(dryRun: Binding<Bool>, isLoading: Bool, onLaunch: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: dryRun) {
                HStack {
                    Text("Dry Run")
                        .foregroundColor(Theme.textPrimary)
                    if !dryRun.wrappedValue {
                        StatusPill(label: "LIVE", color: Theme.red)
                    }
                }
            }
            .tint(Theme.green)

            if engineRunning {
                Text("Stop the current engine first.").font(.caption).foregroundColor(Theme.orange)
            }
            LoadingButton("Launch", isLoading: isLoading, color: Theme.blue) {
                onLaunch()
            }
            .disabled(engineRunning || isLoading)

            if let success = vm.launchSuccess {
                Text(success).font(.caption).foregroundColor(Theme.green)
            }
            if let err = vm.launchError {
                Text(err).font(.caption).foregroundColor(Theme.red)
            }
        }
        .confirmationDialog(
            "⚠️ LIVE Mode — real orders will be placed. Are you sure?",
            isPresented: $vm.showLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Place LIVE Orders", role: .destructive) {
                Task { await vm.confirmLiveAction() }
            }
            Button("Cancel", role: .cancel) {
                vm.cancelLiveAction()
            }
        }
    }
}

// MARK: - Rounded corners helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
