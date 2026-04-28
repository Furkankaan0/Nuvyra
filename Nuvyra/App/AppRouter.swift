import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var dashboardPath: [Route] = []
    @Published var mealPath: [Route] = []
    @Published var walkingPath: [Route] = []
    @Published var presentedSheet: AppSheet?
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case meals
    case walking
    case weekly
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Ritim"
        case .meals: "Öğün"
        case .walking: "Yürüyüş"
        case .weekly: "Hafta"
        case .settings: "Ayarlar"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "sparkle.magnifyingglass"
        case .meals: "fork.knife.circle"
        case .walking: "figure.walk.circle"
        case .weekly: "chart.line.uptrend.xyaxis.circle"
        case .settings: "gearshape.circle"
        }
    }
}

enum Route: Hashable {
    case mealDetail(UUID)
    case paywall
    case privacy
}

enum AppSheet: Identifiable {
    case addMeal
    case photoMeal
    case healthPermission
    case notificationPermission

    var id: String { String(describing: self) }
}
