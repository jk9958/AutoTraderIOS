import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Status", systemImage: "gauge.with.needle") }
            TradeView()
                .tabItem { Label("Trade", systemImage: "bolt.fill") }
            LogsView()
                .tabItem { Label("Logs", systemImage: "doc.text.magnifyingglass") }
            TradesView()
                .tabItem { Label("Positions", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(Theme.blue)
        .preferredColorScheme(.dark)
    }
}
