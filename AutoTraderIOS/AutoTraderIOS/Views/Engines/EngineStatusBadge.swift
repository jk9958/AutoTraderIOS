import SwiftUI

/// Compact pill reflecting an engine's heartbeat-derived run state.
struct EngineStatusBadge: View {
    let state: EngineRunState

    private var color: Color {
        switch state {
        case .running: return Theme.profitGreen
        case .stale:   return .orange
        case .stopped: return .secondary
        case .unknown: return .secondary
        }
    }

    private var label: String {
        switch state {
        case .running: return "Running"
        case .stale:   return "Stale"
        case .stopped: return "Stopped"
        case .unknown: return "Unknown"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
    }
}
