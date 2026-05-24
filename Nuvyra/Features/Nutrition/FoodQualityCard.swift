import SwiftUI

/// Daily nutrition quality summary — composes a 0-100 score, a grade label, and
/// per-micronutrient progress chips (fiber / sodium / sugar / saturated fat).
struct FoodQualityCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedScore: Double = 0

    var totals: NutritionValues
    var target: MacroTarget

    private var score: Int { FoodQualityScore.score(totals: totals, target: target) }
    private var grade: FoodQualityScore.Grade { FoodQualityScore.grade(score) }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                gauge
                chips
                Text("Skor; lif kazanımları ile sodyum, şeker ve doymuş yağ aşımlarına göre hesaplanır. Tıbbi değerlendirme yerine geçmez.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { animate() }
        .onChange(of: score) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Günlük besin kalitesi: \(score), \(grade.title)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Besin kalitesi")
                    .font(NuvyraTypography.section)
                Text(grade.caption)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(grade.tint)
        }
    }

    private var gauge: some View {
        HStack(alignment: .center, spacing: NuvyraSpacing.md) {
            ZStack {
                Circle()
                    .stroke(grade.tint.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(
                        AngularGradient(colors: [grade.tint, grade.tint.opacity(0.5), grade.tint], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("/100")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(grade.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(grade.tint)
                Text("\(target.fiberGrams) g lif, \(target.sodiumMg) mg sodyum, \(target.sugarGrams) g şeker, \(target.saturatedFatGrams) g doymuş yağ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
            chip(title: "Lif", consumed: totals.fiber, target: Double(target.fiberGrams), unit: "g", tint: NuvyraColors.paleLime, lowerIsBetter: false)
            chip(title: "Sodyum", consumed: totals.sodium, target: Double(target.sodiumMg), unit: "mg", tint: NuvyraColors.mutedCoral, lowerIsBetter: true)
            chip(title: "Şeker", consumed: totals.sugar, target: Double(target.sugarGrams), unit: "g", tint: NuvyraColors.softSand, lowerIsBetter: true)
            chip(title: "Doymuş yağ", consumed: totals.saturatedFat, target: Double(target.saturatedFatGrams), unit: "g", tint: NuvyraColors.mutedCoral, lowerIsBetter: true)
        }
    }

    private func chip(title: String, consumed: Double, target: Double, unit: String, tint: Color, lowerIsBetter: Bool) -> some View {
        let ratio = target > 0 ? consumed / target : 0
        let overTarget = ratio > 1
        let isWarning = lowerIsBetter && overTarget
        let displayTint = isWarning ? NuvyraColors.mutedCoral : tint
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(consumed.cleanFormatted) / \(Int(target)) \(unit)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(displayTint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(displayTint.opacity(0.12))
                    Capsule()
                        .fill(displayTint)
                        .frame(width: max(min(proxy.size.width * ratio, proxy.size.width), 0))
                }
            }
            .frame(height: 6)
            if isWarning {
                Text("Önerilen üst sınırın üzerinde")
                    .font(.caption2)
                    .foregroundStyle(NuvyraColors.mutedCoral)
            } else if !lowerIsBetter, ratio < 1 {
                Text(String(format: "Hedefe %%%.0f", ratio * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(displayTint.opacity(0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }

    private func animate() {
        guard !reduceMotion else { animatedScore = Double(score); return }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { animatedScore = Double(score) }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            FoodQualityCard(
                totals: NutritionValues(calories: 1480, protein: 90, carbs: 180, fat: 50, fiber: 22, sodium: 1900, sugar: 35, saturatedFat: 14),
                target: .defaultTarget
            )
            FoodQualityCard(
                totals: NutritionValues(calories: 2300, protein: 110, carbs: 240, fat: 90, fiber: 12, sodium: 3200, sugar: 78, saturatedFat: 32),
                target: .defaultTarget
            )
        }
        .padding()
    }
}
#endif
