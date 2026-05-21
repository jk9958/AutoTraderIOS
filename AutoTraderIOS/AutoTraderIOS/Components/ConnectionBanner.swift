import SwiftUI

struct ConnectionBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(Theme.orange)
            Text(message)
                .font(.footnote)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
            Spacer()
            Button("Retry") { onRetry() }
                .font(.footnote.bold())
                .foregroundColor(Theme.blue)
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "2c1a00"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.orange), alignment: .bottom)
    }
}
