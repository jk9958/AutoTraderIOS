import SwiftUI

struct LoadingButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.blue
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                (isDisabled || isLoading) ? color.opacity(0.45) : color
            )
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }
}

#Preview {
    VStack(spacing: 12) {
        LoadingButton(title: "Launch Engine", icon: "play.fill", color: Theme.green, action: {})
        LoadingButton(title: "Starting...", icon: nil, color: Theme.green, isLoading: true, action: {})
        LoadingButton(title: "Stop Engine", icon: "stop.fill", color: Theme.red, action: {})
        LoadingButton(title: "Engine Running", color: Theme.blue, isDisabled: true, action: {})
    }
    .padding()
    .background(Theme.background)
}
