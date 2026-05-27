import SwiftUI

struct HealthSetupStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Apple Health",
            title: "Adımların otomatik gelsin.",
            subtitle: "Apple Sağlık iznini açarsan Nuvyra adım ve aktivite ritmini manuel giriş gerektirmeden takip eder."
        ) {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(NuvyraColors.mutedCoral, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(viewModel.healthStatusTitle)
                                .font(NuvyraTypography.section)
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text(viewModel.healthStatusDescription)
                                .font(NuvyraTypography.body)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }

                    if viewModel.healthState == .sharingAuthorized {
                        OnboardingConnectedBadge(title: "Apple Sağlık bağlı")
                    } else {
                        NuvyraSecondaryButton(title: "Apple Sağlık iznini aç", systemImage: "heart") {
                            Task { await viewModel.requestHealth(dependencies: dependencies) }
                        }
                    }

                    Divider().opacity(0.35)

                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(NuvyraColors.accent)
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nazik bildirimler")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("Su, öğün ve akşam yürüyüşünü düşük frekansta hatırlatır.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Nazik bildirimler", isOn: $viewModel.wantsNotifications)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }
                }
            }

            SoftNoticeCard(
                title: "Verilerin sende kalır.",
                subtitle: "Sağlık verileri reklam hedefleme için kullanılmaz. İzinleri iPhone Ayarları'ndan istediğin zaman kapatabilirsin.",
                symbol: "lock.shield"
            )
        }
    }
}
