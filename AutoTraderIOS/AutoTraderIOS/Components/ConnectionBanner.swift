import SwiftUI

struct ConnectionBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.headline)
                    .foregroundColor(Theme.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection Lost")
                        .font(.caption.bold())
                        .foregroundColor(Theme.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Retry") { onRetry() }
                        .font(.caption.bold())
                        .foregroundColor(Theme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.blue.opacity(0.15))
                        .cornerRadius(6)

                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(
                ZStack {
                    Theme.orange.opacity(0.08)
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.orange.opacity(0.3), lineWidth: 1)
                }
            )
            .cornerRadius(10)
            .padding(12)
        }
    }
}
