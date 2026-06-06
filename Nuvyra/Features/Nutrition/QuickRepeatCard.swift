import SwiftUI

/// Horizontal rail of the user's most-logged foods. Tapping a chip
/// re-logs that meal onto the selected day with one tap — the fastest
/// path for someone who eats the same breakfast every morning. Renders
/// nothing when there aren't at least a couple of repeat foods yet.
struct QuickRepeatCard: View {
    @Environment(\.colorScheme) private var scheme
    var meals: [FrequentMeal]
    var onTap: (FrequentMeal) -> Void

    var body: some View {
        if !meals.isEmpty {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    header
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: NuvyraSpacing.sm) {
                            ForEach(meals) { meal in
                                chip(for: meal)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
            Text("nutrition.quickRepeat.title")
                .font(NuvyraTypography.section)
            Spacer()
            Text("nutrition.quickRepeat.subtitle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(for meal: FrequentMeal) -> some View {
        Button {
            onTap(meal)
        } label: {
            HStack(spacing: NuvyraSpacing.sm) {
                ZStack {
                    Circle().fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.22 : 0.14))
                    Image(systemName: "plus")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(meal.template.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text("\(meal.template.calories) kcal · \(meal.count)×")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, NuvyraSpacing.sm)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(meal.template.name), \(meal.template.calories) kalori, \(meal.count) kez kaydedildi")
        .accessibilityHint("Bugüne eklemek için dokun.")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground(.animated)
        QuickRepeatCard(
            meals: [
                FrequentMeal(template: MealEntry(name: "Mercimek çorbası", calories: 210, protein: 11), count: 8),
                FrequentMeal(template: MealEntry(name: "Yulaf ezmesi", calories: 320, protein: 12), count: 5),
                FrequentMeal(template: MealEntry(name: "Izgara tavuk", calories: 360, protein: 48), count: 4)
            ],
            onTap: { _ in }
        )
        .padding()
    }
}
#endif
