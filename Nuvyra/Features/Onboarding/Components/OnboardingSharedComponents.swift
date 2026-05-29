import SwiftUI

// MARK: - Layout

/// Standard layout shell used by every onboarding step that asks the user a
/// single question. Renders the small eyebrow tag, the headline, the subtitle
/// and then the caller-provided answer area.
struct PremiumQuestionLayout<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(NuvyraColors.accent)

                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

// MARK: - Hero card

struct PremiumOnboardingHero: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: String
    let value: String
    let caption: String

    @State private var ringRotation: Double = 0
    @State private var iconBreath: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(heroGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(NuvyraColors.softMint.opacity(scheme == .dark ? 0.24 : 0.38))
                        .frame(width: 210, height: 210)
                        .blur(radius: 38)
                        .offset(x: 72, y: -78)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(NuvyraColors.softSand.opacity(scheme == .dark ? 0.16 : 0.28))
                        .frame(width: 240, height: 240)
                        .blur(radius: 44)
                        .offset(x: -88, y: 84)
                }

            // Yavaşça dönen dış halka — ambient motion, dikkat çekmeyen
            // canlılık. ReduceMotion'da statik.
            Circle()
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.44), style: StrokeStyle(lineWidth: 1, dash: [8, 11]))
                .frame(width: 222, height: 222)
                .rotationEffect(.degrees(reduceMotion ? 18 : ringRotation))

            // İkinci, daha açık halka — derinlik için ters yönde döner.
            Circle()
                .strokeBorder(NuvyraColors.softMint.opacity(scheme == .dark ? 0.18 : 0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 14]))
                .frame(width: 178, height: 178)
                .rotationEffect(.degrees(reduceMotion ? -8 : -ringRotation * 0.6))

            VStack(spacing: NuvyraSpacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .heavy))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 20, x: 0, y: 14)
                    .scaleEffect(iconBreath)

                Text(value)
                    .font(.system(size: value.count > 6 ? 32 : 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text(caption)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: NuvyraShadow.card(scheme), radius: 28, x: 0, y: 20)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 48).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                iconBreath = 1.045
            }
        }
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.08, green: 0.10, blue: 0.11), Color(red: 0.04, green: 0.20, blue: 0.17), Color(red: 0.13, green: 0.12, blue: 0.10)]
                : [Color(red: 0.99, green: 0.96, blue: 0.89), Color(red: 0.87, green: 0.97, blue: 0.91), Color(red: 0.94, green: 0.89, blue: 0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Pickable card

struct SelectableOptionCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let subtitle: String
    let symbol: String
    var trailingText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(NuvyraColors.accent.opacity(0.12)),
                        in: Circle()
                    )
                    .shadow(color: isSelected ? NuvyraColors.accent.opacity(0.32) : .clear, radius: 12, x: 0, y: 6)
                    .scaleEffect(isSelected ? 1.05 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: NuvyraSpacing.sm)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(isSelected ? 0.16 : 0.08), in: Capsule())
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.45))
                    .symbolEffect(.bounce, value: isSelected)
            }
            .padding(16)
            .background(
                isSelected ? NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.11) : NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.50 : 0.72),
                in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.55) : Color.white.opacity(scheme == .dark ? 0.08 : 0.36), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? NuvyraColors.accent.opacity(0.16) : .clear, radius: 18, x: 0, y: 10)
            .scaleEffect(isSelected ? 1.015 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(SelectableCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}

/// Tap sırasında küçük bir scale-down feedback (97%) — iOS-native haptic
/// hissi. ReduceMotion otomatik devreden çıkar (animation nil olur).
private struct SelectableCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Small inline cards

struct PremiumBullet: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 32, height: 32)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SummaryMetricCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.54 : 0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous).stroke(tint.opacity(0.18)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) \(unit)")
    }
}

struct SoftNoticeCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.accent.opacity(scheme == .dark ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct RulerHint: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index == 8 || index == 9 ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.22))
                    .frame(width: 3, height: index % 3 == 0 ? 26 : 14)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

struct OnboardingConnectedBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(NuvyraColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
    }
}

// MARK: - Onboarding-only enum helpers

extension Gender {
    var onboardingSymbol: String {
        switch self {
        case .male: "person.fill"
        case .female: "person.fill"
        case .other: "person.2.fill"
        case .preferNotToSay: "questionmark.circle.fill"
        }
    }
}

extension ActivityLevel {
    var onboardingSymbol: String {
        switch self {
        case .sedentary: "chair.fill"
        case .lightlyActive: "figure.walk"
        case .moderatelyActive: "figure.walk.motion"
        case .veryActive: "figure.run"
        case .athlete: "bolt.heart.fill"
        }
    }
}

extension GoalPace {
    var onboardingSymbol: String {
        switch self {
        case .slow: "tortoise.fill"
        case .balanced: "equal.circle.fill"
        case .fast: "hare.fill"
        }
    }
}

extension GoalType {
    var onboardingSubtitle: String {
        switch self {
        case .loseWeight:
            "Nazik kalori açığı, yüksek protein ve gerçekçi adım hedefi."
        case .maintain:
            "Enerji dengesini koruyan sakin günlük ritim."
        case .gainHealthy:
            "Daha yüksek enerji hedefiyle sağlıklı kilo artışı."
        case .gainMuscle:
            "Protein odağı yüksek, kontrollü kalori fazlası."
        case .walkMore:
            "Walking-first planla adımı alışkanlığa çevir."
        case .eatHealthier:
            "Öğün farkındalığını sade ve sürdürülebilir artır."
        case .healthyLiving:
            "Beslenme, su ve hareket dengesini bütünsel kur."
        case .stayFit:
            "Formunu korurken adım ve makro ritmini netleştir."
        }
    }

    var onboardingSymbol: String {
        switch self {
        case .loseWeight: "arrow.down.forward.circle.fill"
        case .maintain: "equal.circle.fill"
        case .gainHealthy: "plus.circle.fill"
        case .gainMuscle: "dumbbell.fill"
        case .walkMore: "figure.walk.circle.fill"
        case .eatHealthier: "leaf.circle.fill"
        case .healthyLiving: "heart.circle.fill"
        case .stayFit: "sparkles"
        }
    }
}
