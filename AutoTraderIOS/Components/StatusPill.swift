import SwiftUI

struct StatusPill: View {
    let label: String
    let color: Color
    var small: Bool = false

    var body: some View {
        Text(label)
            .font(small ? .caption.weight(.semibold) : .caption.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, small ? 8 : 10)
            .padding(.vertical, small ? 3 : 5)
            .background(color)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        StatusPill(label: "Running", color: Theme.green)
        StatusPill(label: "Stopped", color: Theme.red)
        StatusPill(label: "PAPER", color: Theme.orange)
        StatusPill(label: "LIVE", color: Theme.red)
    }
    .padding()
    .background(Theme.background)
}
