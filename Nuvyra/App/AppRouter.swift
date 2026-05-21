import Foundation
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var pendingNutritionAction: NutritionQuickAction?

    func requestNutritionAction(_ action: NutritionQuickAction) {
        selectedTab = .nutrition
        pendingNutritionAction = action
    }
}

enum NutritionQuickAction: Equatable {
    case openAddMeal
    case openVoiceEntry
    case openBarcodeScanner
    case openFoodSearch
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case nutrition
    case walking
    case insights
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Ritim"
        case .nutrition: "Beslenme"
        case .walking: "Yürüyüş"
        case .insights: "İçgörü"
        case .profile: "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "sparkles"
        case .nutrition: "fork.knife"
        case .walking: "figure.walk"
        case .insights: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle"
        }
    }
}
