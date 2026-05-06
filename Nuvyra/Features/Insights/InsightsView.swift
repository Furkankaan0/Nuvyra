import SwiftUI

struct InsightsView: View {
    var body: some View {
        AnalyticsView()
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
