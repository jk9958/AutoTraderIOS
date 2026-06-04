import SwiftUI

/// "System check" — the novice-safe place for technical detail. Renders each
/// dependency as Healthy / Warning / Error with a plain explanation and fix.
struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DiagnosticsVM()

    var body: some View {
        List {
            switch vm.health {
            case .idle, .loading:
                Section { HStack { ProgressView(); Text("Running system check…").foregroundStyle(.secondary) } }
            case .failed(let msg):
                Section {
                    Label("Couldn't run the check", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                    Button("Try Again") { Task { await vm.load(client: appState.client) } }
                }
            case .loaded(let report):
                overallSection(report)
                componentsSection(report)
            }
        }
        .navigationTitle("System Check")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(client: appState.client) }
        .refreshable { await vm.load(client: appState.client) }
    }

    private func overallSection(_ report: HealthDeepResponse) -> some View {
        Section {
            HStack {
                Text("Overall").font(.headline)
                Spacer()
                StatusChip(status: report.overall.appStatus)
            }
            Text(overallMessage(report.overall))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func componentsSection(_ report: HealthDeepResponse) -> some View {
        Section("Details") {
            ForEach(report.sortedComponents, id: \.name) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(DiagnosticsCopy.name(item.name)).font(.subheadline.weight(.medium))
                        Spacer()
                        StatusChip(status: item.health.level.appStatus, compact: true)
                    }
                    if let fix = DiagnosticsCopy.fix(item.name, level: item.health.level) {
                        Label(fix, systemImage: "wrench.and.screwdriver")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func overallMessage(_ level: HealthLevel) -> String {
        switch level {
        case .healthy:  return "Everything the bots rely on is working."
        case .degraded: return "Mostly fine, but one area needs attention. See details below."
        case .failed:   return "Something important is down. Check the details below."
        case .unknown:  return "The server didn't report a clear status."
        }
    }
}
