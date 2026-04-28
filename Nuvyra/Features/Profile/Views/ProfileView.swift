import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    if let profile = appState.profile {
                        let target = viewModel.calorieTarget(for: profile)
                        NuvyraMetricCard(title: "Hedef", value: profile.goal.title, detail: profile.activityLevel.title, systemImage: "target")
                        NuvyraMetricCard(title: "Kalori aralığı", value: target.displayRange, detail: "Tahmini günlük hedef", systemImage: "flame")
                        NuvyraGlassCard {
                            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                                Text("Profil")
                                    .font(NuvyraTypography.sectionTitle())
                                Text("Yaş: \(profile.age)")
                                Text("Boy: \(profile.heightCentimeters) cm")
                                Text("Kilo: \(profile.weightKilograms.roundedInt) kg")
                                if let targetWeight = profile.targetWeightKilograms {
                                    Text("Hedef kilo: \(targetWeight.roundedInt) kg")
                                }
                                Text("Cinsiyet: \(profile.gender.title)")
                            }
                        }
                    } else {
                        EmptyStateCard(title: "Profil bulunamadı", detail: "Onboarding tamamlandığında burada hedeflerin görünecek.", systemImage: "person.crop.circle")
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState.preview())
}
