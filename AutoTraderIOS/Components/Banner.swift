import SwiftUI

enum BannerStyle {
    case error
    case warning
    case info
    case success

    var backgroundColor: Color {
        switch self {
        case .error:   return Theme.red
        case .warning: return Theme.orange
        case .info:    return Theme.blue
        case .success: return Theme.green
        }
    }

    var icon: String {
        switch self {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

struct Banner: View {
    let message: String
    let style: BannerStyle
    var onDismiss: (() -> Void)? = nil
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(style.backgroundColor)
        .cornerRadius(Theme.cornerRadius)
    }
}

#Preview {
    VStack(spacing: 12) {
        Banner(
            message: "Can't reach the server. Check that Tailscale is connected and the server is running.",
            style: .error,
            onDismiss: {},
            actionTitle: "Retry",
            onAction: {}
        )
        Banner(message: "LIVE mode active — real orders will be placed.", style: .warning, onDismiss: {})
        Banner(message: "Engine started successfully.", style: .success, onDismiss: {})
    }
    .padding()
    .background(Theme.background)
}
