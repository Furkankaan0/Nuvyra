import SwiftData
import SwiftUI

@main
@MainActor
struct NuvyraApp: App {
    @StateObject private var dependencies: DependencyContainer
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer

    init() {
        let isUITesting = CommandLine.arguments.contains("-ui-testing")
        modelContainer = isUITesting ? NuvyraModelContainer.uiTesting() : NuvyraModelContainer.live()
        _dependencies = StateObject(wrappedValue: isUITesting ? .preview() : .live())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
                .environmentObject(dependencies)
                .environmentObject(router)
                .task {
                    SeedData.ensureMinimumData(in: modelContainer.mainContext)
                    await dependencies.analytics.track(.appOpened, payload: AnalyticsPayload())
                }
        }
    }
}
