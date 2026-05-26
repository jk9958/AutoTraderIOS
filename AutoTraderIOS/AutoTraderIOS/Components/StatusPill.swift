import SwiftUI

struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption.bold())
                .tracking(0.3)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                color.opacity(0.2)
                Capsule()
                    .stroke(color.opacity(0.4), lineWidth: 1)
            }
        )
        .clipShape(Capsule())
    }
}
