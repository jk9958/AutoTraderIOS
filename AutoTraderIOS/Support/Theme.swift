import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum Theme {
    static let background = Color(hex: "#0d0d0f")
    static let card = Color(hex: "#1c1c1e")
    static let text = Color(hex: "#e2e2e7")
    static let green = Color(hex: "#27ae60")
    static let blue = Color(hex: "#3a7bd5")
    static let orange = Color(hex: "#d68910")
    static let red = Color(hex: "#c0392b")
    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16

    // Derived
    static let textSecondary = Color(hex: "#e2e2e7").opacity(0.55)
    static let cardBorder = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.1)
}
