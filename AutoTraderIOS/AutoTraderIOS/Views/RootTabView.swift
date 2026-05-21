import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.needle")
                }

            TradeView()
                .tabItem {
                    Label("Trade", systemImage: "bolt.fill")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }

            TradesView()
                .tabItem {
                    Label("Trades", systemImage: "chart.bar.xaxis")
                }
        }
        .accentColor(Theme.blue)
        .preferredColorScheme(.dark)
    }
}
