import SwiftUI

struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
            .padding(.horizontal, 4)

            NuvyraGlassCard {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

struct SettingsRow<Accessory: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color
    let accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color = NuvyraColors.accent,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(tint, in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: NuvyraSpacing.sm)
            accessory
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

extension SettingsRow where Accessory == SettingsRowChevron {
    init(title: String, subtitle: String? = nil, systemImage: String, tint: Color = NuvyraColors.accent) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
            SettingsRowChevron()
        }
    }
}

struct SettingsRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
            .opacity(0.45)
    }
}
