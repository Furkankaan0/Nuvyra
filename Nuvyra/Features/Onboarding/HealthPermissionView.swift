import SwiftUI

struct HealthPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        VStack(spacing: NuvyraSpacing.md) {
            PermissionCard(
                icon: "heart.text.square.fill",
                title: viewModel.healthStatusTitle,
                description: viewModel.healthStatusDescription,
                tint: NuvyraColors.mutedCoral
            ) {
                if viewModel.healthState != .sharingAuthorized {
                    NuvyraSecondaryButton(title: "Apple Sağlık iznini aç", systemImage: "heart") {
                        Task { await viewModel.requestHealth(dependencies: dependencies) }
                    }
                } else {
                    ConnectedBadge(title: "Bağlandı")
                }
            }

            NotificationPreferenceCard(wantsNotifications: $viewModel.wantsNotifications)

            privacyFootnote
        }
    }

    private var privacyFootnote: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            Image(systemName: "lock.shield")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NuvyraColors.accent)
            Text("Sağlık verilerin reklam hedefleme için kullanılmaz. Nuvyra tıbbi tavsiye vermez; değerler wellness içgörüsü ve tahmini hedefler içindir.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionCard<Accessory: View>: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var title: String
    var description: String
    var tint: Color
    let accessory: Accessory

    init(
        icon: String,
        title: String,
        description: String,
        tint: Color,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                    Image(systemName: icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(tint, in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                        Text(title)
                            .font(NuvyraTypography.section)
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                        Text(description)
                            .font(NuvyraTypography.body)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                accessory
            }
        }
    }
}

private struct NotificationPreferenceCard: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var wantsNotifications: Bool

    var body: some View {
        NuvyraGlassCard {
            HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(NuvyraColors.accent, in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    Text("Nazik bildirimler")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text("Su, öğün ve akşam yürüyüşünü hatırlatan düşük frekanslı bildirimler.")
                        .font(NuvyraTypography.body)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                Spacer(minLength: NuvyraSpacing.sm)

                Toggle("Nazik bildirimler iste", isOn: $wantsNotifications)
                    .labelsHidden()
                    .tint(NuvyraColors.accent)
                    .accessibilityLabel("Nazik bildirimler iste")
            }
        }
    }
}

private struct ConnectedBadge: View {
    var title: String

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(NuvyraColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
    }
}
