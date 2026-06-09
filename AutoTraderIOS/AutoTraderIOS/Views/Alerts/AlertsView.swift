import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AlertsVM()

    var body: some View {
        NavigationStack {
            Group {
                if vm.alerts.isEmpty && vm.isLoading {
                    ProgressView("Loading alerts…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.alerts.isEmpty {
                    ContentUnavailableView(
                        "No alerts",
                        systemImage: "bell.slash",
                        description: Text(vm.error ?? "You're all caught up.")
                    )
                } else {
                    List(vm.alerts) { alert in
                        AlertRow(alert: alert)
                    }
                }
            }
            .navigationTitle("Alerts")
            .refreshable { await vm.reload(appState: appState) }
            .task { vm.start(appState: appState) }
            .onDisappear { vm.stop() }
        }
    }
}

private struct AlertRow: View {
    let alert: Alert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.message ?? "—")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    if let src = alert.source {
                        Text(src).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let ts = alert.timestamp {
                        Text(ts).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        switch alert.level {
        case .critical: return Theme.red
        case .warning: return Theme.orange
        case .info: return Theme.blue
        }
    }

    private var icon: String {
        switch alert.level {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}
