import SwiftUI

/// "More" tab — secondary destinations and the advanced (power-user) surface that
/// preserves the original engineer-facing screens for backward compatibility.
struct MoreView: View {
    @EnvironmentObject var appState: AppState
    @State private var sheet: MoreSheet?

    enum MoreSheet: Identifiable {
        case brokers, logs, settings, manual, trend
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account & monitoring") {
                    row("Brokers", "building.columns.fill", .purple) { sheet = .brokers }
                    NavigationLink { DiagnosticsView() } label: { label("System check", "stethoscope", .blue) }
                    row("Activity logs", "doc.text.magnifyingglass", .teal) { sheet = .logs }
                }

                Section("App") {
                    row("Settings", "gearshape.fill", .gray) { sheet = .settings }
                    NavigationLink { HelpView() } label: { label("Help", "questionmark.circle.fill", .blue) }
                }

                Section {
                    row("Manual trading", "slider.horizontal.3", .orange) { sheet = .manual }
                    row("Trend bot (advanced)", "brain.head.profile", .indigo) { sheet = .trend }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("The original power-user controls. Most people can ignore this section.")
                }

                Section {
                    LabeledContent("Version",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Connection", value: appState.isOnline ? "Online" : "Offline")
                }
            }
            .navigationTitle("More")
            .sheet(item: $sheet) { which in
                switch which {
                case .brokers:  DashboardView()
                case .logs:     LogsView()
                case .settings: SettingsView()
                case .manual:   TradeView()
                case .trend:    TrendAgentView()
                }
            }
        }
    }

    private func row(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { label(title, icon, tint) }
            .buttonStyle(.plain)
    }

    private func label(_ title: String, _ icon: String, _ tint: Color) -> some View {
        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
    }
}
