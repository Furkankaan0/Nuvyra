import SwiftUI

/// First-24-hour guided checklist. Replaces the generic empty-state card on
/// brand-new accounts and quietly fades out once every step is done (or the
/// user explicitly dismisses it).
struct DayOneTourCard: View {
    enum Step: String, CaseIterable, Identifiable {
        case firstMeal
        case firstWater
        case viewSteps

        var id: String { rawValue }
        var title: String {
            switch self {
            case .firstMeal: "İlk öğününü ekle"
            case .firstWater: "İlk su kaydını yap"
            case .viewSteps: "Bugünkü adımları gör"
            }
        }
        var subtitle: String {
            switch self {
            case .firstMeal: "Kahvaltı, öğle veya akşam — birkaç saniyede ekleyebilirsin."
            case .firstWater: "200 ml küçük bir bardak iyi bir başlangıç."
            case .viewSteps: "Apple Health iznini açtıysan adımlar otomatik gelir."
            }
        }
        var systemImage: String {
            switch self {
            case .firstMeal: "fork.knife"
            case .firstWater: "drop.fill"
            case .viewSteps: "figure.walk"
            }
        }
        var tint: Color {
            switch self {
            case .firstMeal: NuvyraColors.accent
            case .firstWater: Color(red: 0.20, green: 0.56, blue: 0.95)
            case .viewSteps: NuvyraColors.softMint
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var completed: Set<Step>
    var onTapStep: (Step) -> Void
    var onDismiss: () -> Void

    private var progress: Double {
        Double(completed.count) / Double(Step.allCases.count)
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                progressBar
                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(Step.allCases) { step in
                        row(for: step)
                    }
                }
                Button("Şimdilik geç", action: onDismiss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("İlk gün turu, \(completed.count)/\(Step.allCases.count) tamamlandı")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 44, height: 44)
                .background(NuvyraColors.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Nuvyra'ya başlayalım")
                    .font(NuvyraTypography.section)
                Text("İlk üç adımı tamamlamak ritmini birkaç saniyede kurar.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(NuvyraColors.accent.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(proxy.size.width * progress, 0))
                        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78), value: progress)
                }
            }
            .frame(height: 8)
            Text("\(completed.count)/\(Step.allCases.count) tamamlandı")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func row(for step: Step) -> some View {
        let isDone = completed.contains(step)
        return Button {
            onTapStep(step)
        } label: {
            HStack(spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .fill(step.tint.opacity(isDone ? 1 : 0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: isDone ? "checkmark" : step.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isDone ? .white : step.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    Text(step.subtitle)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isDone ? "checkmark.circle.fill" : "arrow.forward.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDone ? step.tint : .secondary.opacity(0.6))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isDone ? "Tamamlandı" : "Açmak için dokun")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        DayOneTourCard(
            completed: [.firstWater],
            onTapStep: { _ in },
            onDismiss: {}
        )
        .padding()
    }
}
#endif
