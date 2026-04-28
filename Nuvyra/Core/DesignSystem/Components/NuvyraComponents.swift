import SwiftUI

struct NuvyraGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(NuvyraSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: NuvyraSpacing.cardRadius, style: .continuous)
                    .fill(NuvyraColor.card(for: colorScheme))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraSpacing.cardRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: NuvyraSpacing.cardRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 22, x: 0, y: 12)
    }
}

struct NuvyraMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var value: String
    var detail: String
    var systemImage: String
    var tint: Color?

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(tint ?? NuvyraColor.primary(for: colorScheme))
                    Text(title)
                        .font(NuvyraTypography.caption())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(value)
                    .font(NuvyraTypography.metric())
                    .foregroundStyle(NuvyraColor.textPrimary(for: colorScheme))
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(NuvyraTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NuvyraProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme
    var progress: Double
    var lineWidth: CGFloat = 14
    var centerText: String
    var caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(NuvyraColor.primary(for: colorScheme).opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [NuvyraColor.primary(for: colorScheme), NuvyraColor.accent(for: colorScheme)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(centerText)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text(caption)
                    .font(NuvyraTypography.caption())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(NuvyraColor.textPrimary(for: colorScheme))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("İlerleme \(Int(progress * 100)) yüzde")
    }
}

struct NuvyraPrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var systemImage: String?
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            NuvyraHaptics.softTap()
            action()
        } label: {
            HStack(spacing: NuvyraSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [NuvyraColor.primary(for: colorScheme), NuvyraColor.accent(for: colorScheme)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityAddTraits(.isButton)
    }
}

struct NuvyraSecondaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button {
            NuvyraHaptics.softTap()
            action()
        } label: {
            HStack(spacing: NuvyraSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(NuvyraColor.primary(for: colorScheme))
            .background(NuvyraColor.primary(for: colorScheme).opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NuvyraChip: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            NuvyraHaptics.softTap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : NuvyraColor.textPrimary(for: colorScheme))
                .background(
                    isSelected ? NuvyraColor.primary(for: colorScheme) : NuvyraColor.card(for: colorScheme),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(NuvyraColor.primary(for: colorScheme).opacity(0.22))
                }
        }
        .buttonStyle(.plain)
    }
}

struct NuvyraPaywallFeatureRow: View {
    var title: String

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(NuvyraColor.lightPrimary)
            Text(title)
                .font(NuvyraTypography.body())
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct NuvyraPermissionCard: View {
    var title: String
    var bodyText: String
    var systemImage: String
    var primaryTitle: String
    var secondaryTitle: String?
    var primaryAction: () -> Void
    var secondaryAction: (() -> Void)?

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(NuvyraColor.lightPrimary)
                Text(title)
                    .font(NuvyraTypography.title())
                Text(bodyText)
                    .font(NuvyraTypography.body())
                    .foregroundStyle(.secondary)
                NuvyraPrimaryButton(title: primaryTitle, systemImage: "arrow.right", action: primaryAction)
                if let secondaryTitle, let secondaryAction {
                    NuvyraSecondaryButton(title: secondaryTitle, systemImage: nil, action: secondaryAction)
                }
            }
        }
    }
}

struct NuvyraWeeklyInsightCard: View {
    var summary: WeeklySummary

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Haftalık koç özeti", systemImage: "sparkles")
                    .font(NuvyraTypography.sectionTitle())
                Text(summary.insight)
                    .font(NuvyraTypography.body())
                    .foregroundStyle(.secondary)
                ForEach(summary.suggestions, id: \.self) { suggestion in
                    NuvyraPaywallFeatureRow(title: suggestion)
                }
            }
        }
    }
}

struct NuvyraStepGoalCard: View {
    var snapshot: StepSnapshot

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(
                    progress: snapshot.progress,
                    lineWidth: 10,
                    centerText: "\(Int(snapshot.progress * 100))%",
                    caption: "adım"
                )
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    Text("Bugünkü adımlar")
                        .font(NuvyraTypography.sectionTitle())
                    Text("\(snapshot.steps.formatted()) / \(snapshot.goal.formatted())")
                        .font(.title3.weight(.bold))
                    Text(snapshot.remainingSteps == 0 ? "Hedef tamamlandı." : "\(snapshot.remainingSteps.formatted()) adım kaldı.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}

struct NuvyraMealCard: View {
    var meal: MealLog

    var body: some View {
        NuvyraGlassCard {
            HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [NuvyraColor.lightPrimary.opacity(0.24), NuvyraColor.lightSecondaryAccent.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(Image(systemName: meal.source == .photo ? "camera.macro" : "fork.knife").foregroundStyle(NuvyraColor.lightPrimary))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(meal.name)
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Text("\(meal.calories) kcal")
                            .font(.subheadline.weight(.bold))
                    }
                    Text(meal.macros.summary)
                        .font(NuvyraTypography.caption())
                        .foregroundStyle(.secondary)
                    HStack(spacing: NuvyraSpacing.xs) {
                        Text(DateFormatter.nuvyraTime.string(from: meal.loggedAt))
                        if meal.isEstimated {
                            Text("Tahmini değer")
                        }
                    }
                    .font(NuvyraTypography.caption())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Metric") {
    NuvyraMetricCard(title: "Kalori", value: "1.240", detail: "Bugün alınan", systemImage: "flame.fill")
        .padding()
        .background(NuvyraColor.lightBackground)
}

#Preview("Meal") {
    NuvyraMealCard(meal: MealLog.sampleToday[0])
        .padding()
        .background(NuvyraColor.lightBackground)
}
