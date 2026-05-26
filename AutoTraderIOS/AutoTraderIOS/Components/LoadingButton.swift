import SwiftUI

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let role: ButtonRole?
    let color: Color
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, role: ButtonRole? = nil,
         color: Color = Theme.blue, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.role = role
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: role == .destructive ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption.bold())
                        .opacity(0.8)
                }

                Text(title)
                    .font(.subheadline.bold())
                    .tracking(0.3)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(isLoading ? 0.5 : 0.9),
                            color.opacity(isLoading ? 0.4 : 0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
    }
}
