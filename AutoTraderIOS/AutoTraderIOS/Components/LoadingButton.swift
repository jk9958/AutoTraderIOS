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
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isLoading ? color.opacity(0.6) : color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}
