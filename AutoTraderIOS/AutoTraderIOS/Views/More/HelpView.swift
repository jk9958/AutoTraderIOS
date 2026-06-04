import SwiftUI

/// Plain-language "how it works" + glossary so a first-timer can self-serve.
struct HelpView: View {
    var body: some View {
        List {
            Section("How it works") {
                helpRow("1. Connect a broker", "Your broker is the account that places real trades. Connect it from More → Brokers.")
                helpRow("2. Create a bot", "A bot trades automatically using a style you choose. Start in Practice mode.")
                helpRow("3. Start it", "Run the bot. The Home tab shows what's happening at a glance.")
                helpRow("4. Watch Activity", "See live profit/loss and your trade history in the Activity tab.")
            }

            Section("Words you'll see") {
                glossary("Bot", "A small program that trades automatically for you.")
                glossary("Broker", "Your trading account (e.g. Zerodha, Fyers) that places the trades.")
                glossary("Trading style", "The rules a bot follows — like Range Income or Trend Follower.")
                glossary("Practice mode", "Simulated trading. No real money is used.")
                glossary("Live mode", "Real trades with real money.")
                glossary("Admin access code", "Unlocks making changes like creating or starting bots.")
                glossary("Live P&L", "Your profit or loss right now on open positions.")
            }

            Section("Staying safe") {
                Label("Bots default to Practice mode. Going Live always asks you to confirm.",
                      systemImage: "checkmark.shield")
                    .font(.callout)
                Label("Your admin code is stored securely on this device only.",
                      systemImage: "lock.fill")
                    .font(.callout)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(body).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func glossary(_ term: String, _ def: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term).font(.subheadline.weight(.semibold))
            Text(def).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
