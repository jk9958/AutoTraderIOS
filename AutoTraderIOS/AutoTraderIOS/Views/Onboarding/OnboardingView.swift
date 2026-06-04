import SwiftUI

/// First-launch, 4-page guided intro. Gated by the `didOnboard` UserDefaults
/// flag (see `RootTabView`). Plain language only — no trading jargon.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("didOnboard") private var didOnboard = false

    @State private var page = 0
    @State private var serverURL = ""
    @State private var apiKey = ""

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                connectServer.tag(1)
                connectBroker.tag(2)
                ready.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .onAppear { serverURL = appState.serverBaseURL; apiKey = appState.apiKey }
        .interactiveDismissDisabled()
    }

    // MARK: Pages

    private var welcome: some View {
        page(icon: "hand.wave.fill", tint: .blue, title: "Welcome to AutoTrader") {
            Text("AutoTrader runs trading **bots** for you — small programs that buy and sell automatically using a strategy and your broker account.")
            Text("Everything starts in **Practice mode**, so you can explore safely with no real money.")
                .foregroundStyle(.secondary)
        }
    }

    private var connectServer: some View {
        page(icon: "server.rack", tint: .indigo, title: "Connect to your server") {
            Text("Your bots run on a server. Enter its address and your **admin access code** (used to make changes).")
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                TextField("https://your-server.com", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Admin access code (optional now)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
            }
            Text("You can add or change these later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var connectBroker: some View {
        page(icon: "building.columns.fill", tint: .purple, title: "Connect a broker") {
            Text("A **broker** is the account that actually places trades — like Zerodha or Fyers.")
                .foregroundStyle(.secondary)
            Text("Broker logins expire daily, so you'll reconnect from time to time. You can do this any time from **More → Brokers**.")
                .foregroundStyle(.secondary)
            Label("You can skip this for now and still use Practice mode.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var ready: some View {
        page(icon: "checkmark.seal.fill", tint: Theme.profitGreen, title: "You're all set") {
            Text("Create a bot any time from the **Bots** tab. Pick a style, choose your broker, and start in Practice mode.")
                .foregroundStyle(.secondary)
            Text("The **Home** tab always shows what's running, your live profit/loss, and anything that needs your attention.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            if page == lastPage {
                Button(action: finish) {
                    Text("Get started").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip") { finish() }
                    .font(.subheadline)
            }
        }
    }

    private func finish() {
        // Persist whatever the user entered (also routed through AppState/Keychain).
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty { appState.serverBaseURL = trimmedURL }
        if appState.apiKey != apiKey { appState.apiKey = apiKey }
        Analytics.shared.track(.onboardingCompleted)
        withAnimation { didOnboard = true }
    }

    // MARK: Page scaffold

    @ViewBuilder
    private func page<Content: View>(icon: String, tint: Color, title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(tint)
                    .padding(.top, 48)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 14) { content() }
                    .font(.body)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
