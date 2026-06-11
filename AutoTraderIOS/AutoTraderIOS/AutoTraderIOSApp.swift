import SwiftUI

@main
struct AutoTraderIOSApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundHealthManager.register()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .task {
                    BackgroundHealthManager.requestNotificationPermission()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundHealthManager.schedule()
            }
        }
    }
}
