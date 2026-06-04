import SwiftUI

/// The single visual status vocabulary used across every screen so novices learn
/// one set of colors + icons + words. Never color-only (accessibility).
enum AppStatus: Equatable {
    case running
    case starting
    case stopping
    case stopped
    case notResponding
    case connected
    case disconnected
    case healthy
    case warning
    case error
    case unknown

    var label: String {
        switch self {
        case .running:        return "Running"
        case .starting:       return "Starting"
        case .stopping:       return "Stopping"
        case .stopped:        return "Stopped"
        case .notResponding:  return "Not responding"
        case .connected:      return "Connected"
        case .disconnected:   return "Disconnected"
        case .healthy:        return "Healthy"
        case .warning:        return "Warning"
        case .error:          return "Error"
        case .unknown:        return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .running, .connected, .healthy: return "checkmark.circle.fill"
        case .starting, .stopping:           return "clock.fill"
        case .stopped, .disconnected:        return "pause.circle.fill"
        case .notResponding, .warning:       return "exclamationmark.triangle.fill"
        case .error:                         return "xmark.octagon.fill"
        case .unknown:                       return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .running, .connected, .healthy: return Theme.profitGreen
        case .starting, .stopping:           return .blue
        case .stopped, .disconnected, .unknown: return .secondary
        case .notResponding, .warning:       return .orange
        case .error:                         return Theme.lossRed
        }
    }

    /// Maps an engine heartbeat run-state to the shared vocabulary.
    init(runState: EngineRunState) {
        switch runState {
        case .running: self = .running
        case .stale:   self = .notResponding
        case .stopped: self = .stopped
        case .unknown: self = .unknown
        }
    }
}

/// Reusable status pill: colored dot/icon + word. VoiceOver reads the word, so the
/// meaning never depends on color alone.
struct StatusChip: View {
    let status: AppStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImage)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(status.color)
            Text(status.label)
                .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(status.color.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.label)")
    }
}
