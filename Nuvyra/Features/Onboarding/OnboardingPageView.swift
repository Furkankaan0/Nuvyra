import SwiftUI

struct OnboardingPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    var page: OnboardingPageContent
    var progress: Double

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            OnboardingHeroVisual(page: page, progress: progress)

            VStack(spacing: NuvyraSpacing.md) {
                Text(page.eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(NuvyraColors.accent)

                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.82)

                Text(page.subtitle)
                    .font(.title3.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 345)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title) \(page.subtitle)")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: progress)
    }
}

private struct OnboardingHeroVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    var page: OnboardingPageContent
    var progress: Double

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(heroGradient)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(NuvyraColors.softMint.opacity(scheme == .dark ? 0.28 : 0.34))
                        .frame(width: 170, height: 170)
                        .blur(radius: 32)
                        .offset(x: -45, y: -45)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(NuvyraColors.paleLime.opacity(scheme == .dark ? 0.16 : 0.26))
                        .frame(width: 210, height: 210)
                        .blur(radius: 42)
                        .offset(x: 70, y: 58)
                }

            Circle()
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.42), style: StrokeStyle(lineWidth: 1, dash: [7, 10]))
                .frame(width: 218, height: 218)
                .rotationEffect(.degrees(reduceMotion ? 0 : clampedProgress * 28))

            NuvyraProgressRing(progress: clampedProgress, lineWidth: 14, center: page.metric, caption: page.metricCaption)
                .frame(width: 176, height: 176)
                .shadow(color: NuvyraColors.accent.opacity(0.18), radius: 28, x: 0, y: 20)

            Image(systemName: page.systemImage)
                .font(.system(size: 34, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(
                    LinearGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.softMint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 22, x: 0, y: 14)
                .offset(x: 92, y: 78)

            VStack(alignment: .leading, spacing: 3) {
                Text("Bugün")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                Text("Nazik plan")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(scheme == .dark ? 0.10 : 0.38)))
            .offset(x: -84, y: 78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 278)
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
        .shadow(color: NuvyraShadow.card(scheme), radius: 26, x: 0, y: 18)
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [
                    Color(red: 0.09, green: 0.13, blue: 0.15),
                    Color(red: 0.05, green: 0.18, blue: 0.17),
                    Color(red: 0.08, green: 0.10, blue: 0.11)
                ]
                : [
                    Color(red: 0.98, green: 0.97, blue: 0.92),
                    Color(red: 0.87, green: 0.96, blue: 0.90),
                    Color(red: 0.96, green: 0.90, blue: 0.78)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
