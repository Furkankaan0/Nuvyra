import SwiftUI

@main
@MainActor
struct NuvyraApp: App {
    @StateObject private var appState = AppState.launch()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .task {
                    await appState.loadInitialData()
                }
        }
    }
}
