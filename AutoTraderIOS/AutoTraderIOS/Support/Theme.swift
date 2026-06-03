import SwiftUI

enum Theme {
    // MARK: - Accent Colors
    static let profitGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let lossRed     = Color(red: 0.91, green: 0.30, blue: 0.24)

    // Legacy aliases used across the app
    static let green        = Color.green
    static let blue         = Color.blue
    static let orange       = Color.orange
    static let red          = Color.red
    static let successGreen = Color.green

    // MARK: - Geometry
    static let radius: CGFloat     = 20
    static let cardRadius: CGFloat = 16
    static let pad: CGFloat        = 16
    static let gutter: CGFloat     = 12
}

// MARK: - Glass Card Modifier

private struct GlassCardModifier: ViewModifier {
    let radius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func glassCard(radius: CGFloat = Theme.cardRadius, material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCardModifier(radius: radius, material: material))
    }

    func thinGlassCard(radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(GlassCardModifier(radius: radius, material: .thinMaterial))
    }

    // Legacy compat — used by old call sites
    func cardStyle() -> some View {
        padding(Theme.pad).glassCard()
    }

    func glassStyle() -> some View {
        padding(Theme.pad).glassCard()
    }
}

// MARK: - Color hex init (compatibility)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
