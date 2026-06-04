import SwiftUI

/// A brief confirmation shown after an action (start/stop/restart/delete…), so the
/// user always knows whether it succeeded — independent of how fast the status
/// heartbeat catches up.
struct ToastMessage: Equatable, Identifiable {
    enum Style { case success, error, info }
    let id = UUID()
    let text: String
    let style: Style

    static func success(_ text: String) -> ToastMessage { .init(text: text, style: .success) }
    static func error(_ text: String)   -> ToastMessage { .init(text: text, style: .error) }
    static func info(_ text: String)     -> ToastMessage { .init(text: text, style: .info) }

    var systemImage: String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
    var tint: Color {
        switch style {
        case .success: return Theme.profitGreen
        case .error:   return Theme.lossRed
        case .info:    return .blue
        }
    }
}

extension View {
    /// Presents a transient toast at the bottom; auto-dismisses after a few seconds.
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let m = message {
                    HStack(spacing: 10) {
                        Image(systemName: m.systemImage).foregroundStyle(m.tint)
                        Text(m.text).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(m.tint.opacity(0.3), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)
                    .task(id: m.id) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { message = nil }
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: message)
    }
}
