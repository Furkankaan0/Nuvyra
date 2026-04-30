import Foundation
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
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
        case .dashboard: return "Ritim"
        case .nutrition: return "Beslenme"
        case .walking: return "Yürüyüş"
        case .insights: return "İçgörü"
        case .profile: return "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "sparkles"
        case .nutrition: return "fork.knife"
        case .walking: return "figure.walk"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.crop.circle"
        }
    }
}
