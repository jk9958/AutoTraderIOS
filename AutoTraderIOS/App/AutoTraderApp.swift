import SwiftUI

@main
struct AutoTraderApp: App {
    @StateObject private var apiClient = APIClient()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(apiClient)
                .preferredColorScheme(.dark)
        }
    }
}
