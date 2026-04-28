import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    func refresh(appState: AppState) async {
        isRefreshing = true
        await appState.refreshSteps()
        isRefreshing = false
    }

    func greeting(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<18: return "İyi günler"
        default: return "İyi akşamlar"
        }
    }
}
