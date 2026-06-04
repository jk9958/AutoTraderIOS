import SwiftUI

enum RootTab: Hashable {
    case home, bots, activity, more
}

struct RootTabView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(RootTab.home)

            BotsListView()
                .tabItem { Label("Bots", systemImage: "server.rack") }
                .tag(RootTab.bots)

            ActivityView()
                .tabItem { Label("Activity", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(RootTab.activity)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(RootTab.more)
        }
        .tint(.blue)
        .onAppear { appState.startPolling() }   // app-scoped; leaf screens must not stop it
        .fullScreenCover(isPresented: Binding(get: { !didOnboard }, set: { didOnboard = !$0 })) {
            OnboardingView()
        }
    }
}
