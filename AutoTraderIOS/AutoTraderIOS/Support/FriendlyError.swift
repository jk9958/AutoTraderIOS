import SwiftUI

/// Turns any thrown error into novice-friendly guidance: what happened, how to
/// fix it, and whether a retry makes sense. Screens render this instead of raw
/// HTTP codes or decoding messages.
struct FriendlyError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let fix: String?
    let systemImage: String
    let isRetryable: Bool
    /// True when the fix lives in Settings (caller can route there).
    let pointsToSettings: Bool

    static func from(_ error: Error) -> FriendlyError {
        guard let api = error as? APIError else {
            return FriendlyError(
                title: "Something went wrong",
                message: error.localizedDescription,
                fix: "Please try again.",
                systemImage: "exclamationmark.triangle.fill",
                isRetryable: true,
                pointsToSettings: false
            )
        }
        switch api {
        case .noNetwork:
            return .init(title: "Can't reach the server",
                         message: "We couldn't connect.",
                         fix: "Check your internet connection and that the server is on, then try again.",
                         systemImage: "wifi.slash", isRetryable: true, pointsToSettings: false)
        case .timeout:
            return .init(title: "Taking too long",
                         message: "The server didn't respond in time.",
                         fix: "It may be waking up. Wait a moment and try again.",
                         systemImage: "clock.badge.exclamationmark", isRetryable: true, pointsToSettings: false)
        case .wrongBaseURL:
            return .init(title: "Server address looks wrong",
                         message: "We couldn't find a server at that address.",
                         fix: "Check the server address in Settings.",
                         systemImage: "link.badge.plus", isRetryable: false, pointsToSettings: true)
        case .unauthorized:
            return .init(title: "Admin code needed",
                         message: "The server didn't accept your admin access code.",
                         fix: "Add or fix your admin access code in Settings.",
                         systemImage: "key.slash", isRetryable: false, pointsToSettings: true)
        case .serverKeyNotConfigured:
            return .init(title: "Changes aren't enabled",
                         message: "This server hasn't been set up to allow changes from the app.",
                         fix: "Ask whoever runs the server to set an admin code.",
                         systemImage: "lock.slash", isRetryable: false, pointsToSettings: false)
        case .engineAlreadyRunning:
            return .init(title: "Already running",
                         message: "A bot is already running.",
                         fix: "Stop it first, or pick a different bot.",
                         systemImage: "bolt.badge.clock", isRetryable: false, pointsToSettings: false)
        case .validationError(let msgs):
            return .init(title: "Check your entries",
                         message: msgs.joined(separator: "\n"),
                         fix: "Fix the highlighted fields and try again.",
                         systemImage: "exclamationmark.bubble", isRetryable: false, pointsToSettings: false)
        case .httpError(let code, _):
            if code >= 500 {
                return .init(title: "Server hiccup",
                             message: "The server ran into a problem.",
                             fix: "It's not your fault — try again shortly.",
                             systemImage: "exclamationmark.icloud", isRetryable: true, pointsToSettings: false)
            }
            return .init(title: "Request failed",
                         message: api.errorDescription ?? "The request didn't go through.",
                         fix: "Please try again.",
                         systemImage: "exclamationmark.triangle.fill", isRetryable: true, pointsToSettings: false)
        case .decodingError:
            return .init(title: "Unexpected response",
                         message: "The app couldn't read the server's reply.",
                         fix: "Update the app if a new version is available, or try again.",
                         systemImage: "doc.badge.gearshape", isRetryable: true, pointsToSettings: false)
        case .unknown(let msg):
            return .init(title: "Something went wrong",
                         message: msg,
                         fix: "Please try again.",
                         systemImage: "exclamationmark.triangle.fill", isRetryable: true, pointsToSettings: false)
        }
    }
}

/// Drop-in friendly error card with optional Retry / Open Settings actions.
struct FriendlyErrorView: View {
    let error: FriendlyError
    var onRetry: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: error.systemImage)
        } description: {
            VStack(spacing: 6) {
                Text(error.message)
                if let fix = error.fix { Text(fix).foregroundStyle(.secondary) }
            }
        } actions: {
            if error.pointsToSettings, let onOpenSettings {
                Button("Open Settings", action: onOpenSettings).buttonStyle(.borderedProminent)
            }
            if error.isRetryable, let onRetry {
                Button("Try Again", action: onRetry)
            }
        }
    }
}
