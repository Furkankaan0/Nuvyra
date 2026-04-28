import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showingPrivacy = false
}
