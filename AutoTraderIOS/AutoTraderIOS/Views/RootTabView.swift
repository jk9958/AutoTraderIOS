import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Status", systemImage: "gauge.with.needle") }
            EnginesListView()
                .tabItem { Label("Engines", systemImage: "server.rack") }
            TradeView()
                .tabItem { Label("Trade", systemImage: "bolt.fill") }
            TrendAgentView()
                .tabItem { Label("Trend", systemImage: "brain.head.profile") }
            LogsView()
                .tabItem { Label("Logs", systemImage: "doc.text.magnifyingglass") }
            TradesView()
                .tabItem { Label("Positions", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(.blue)
    }
}
