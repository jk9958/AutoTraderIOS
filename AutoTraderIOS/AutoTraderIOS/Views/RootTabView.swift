import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Status", systemImage: "gauge.with.needle") }
            EnginesView()
                .tabItem { Label("Engines", systemImage: "cpu") }
            BrokersView()
                .tabItem { Label("Brokers", systemImage: "link") }
            PositionsView()
                .tabItem { Label("Positions", systemImage: "chart.bar.fill") }
            LogsView()
                .tabItem { Label("Logs", systemImage: "doc.text.magnifyingglass") }
            TradesView()
                .tabItem { Label("Trades", systemImage: "list.bullet.rectangle") }
            PnLView()
                .tabItem { Label("P&L", systemImage: "chart.line.uptrend.xyaxis") }
            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
        }
        .tint(Theme.blue)
        .preferredColorScheme(.dark)
    }
}
