import SwiftUI
import UIKit

struct RootTabView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)

            TradeView()
                .tabItem {
                    Label("Trade", systemImage: "play.circle.fill")
                }
                .tag(1)

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "terminal")
                }
                .tag(2)

            TradesView()
                .tabItem {
                    Label("Trades", systemImage: "list.clipboard.fill")
                }
                .tag(3)
        }
        .accentColor(Theme.blue)
        .onAppear {
            // Dark tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Theme.card)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
