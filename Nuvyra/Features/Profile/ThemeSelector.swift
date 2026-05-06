import SwiftUI

enum NuvyraThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistem"
        case .light: "Açık"
        case .dark: "Koyu"
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }
}

struct ThemeSelector: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("nuvyra.theme.preference") private var storedPreference = NuvyraThemePreference.system.rawValue

    private var selection: NuvyraThemePreference {
        NuvyraThemePreference(rawValue: storedPreference) ?? .system
    }

    var body: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            ForEach(NuvyraThemePreference.allCases) { preference in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        storedPreference = preference.rawValue
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: preference.symbol)
                        Text(preference.title)
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selection == preference ? .white : NuvyraColors.primaryText(scheme))
                    .background(selection == preference ? NuvyraColors.accent : NuvyraColors.card(scheme).opacity(0.48), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tema \(preference.title)")
                .accessibilityValue(selection == preference ? "Seçili" : "Seçili değil")
            }
        }
    }
}
