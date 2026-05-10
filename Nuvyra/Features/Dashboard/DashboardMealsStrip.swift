import SwiftUI

struct DashboardMealsStrip: View {
    @Environment(\.colorScheme) private var scheme
    var meals: [MealEntry]
    var onSelect: (MealType) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bugünkü öğünler")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 3) {
                        Text("Tümü")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tüm öğünleri gör")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(MealType.allCases) { type in
                        let typeMeals = meals.filter { $0.mealType == type }
                        let totalCalories = typeMeals.reduce(0) { $0 + $1.calories }
                        MealPill(
                            type: type,
                            count: typeMeals.count,
                            totalCalories: totalCalories,
                            firstName: typeMeals.first?.name,
                            action: { onSelect(type) }
                        )
                    }
                }
            }
        }
    }
}

private struct MealPill: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var type: MealType
    var count: Int
    var totalCalories: Int
    var firstName: String?
    var action: () -> Void
    @State private var pressed = false

    private var isEmpty: Bool { count == 0 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isEmpty ? NuvyraColors.accent.opacity(0.10) : NuvyraColors.accent.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: type.systemImage)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    Text(type.title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                    if isEmpty {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent.opacity(0.6))
                    }
                }

                if isEmpty {
                    Text("Ekle")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(totalCalories)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                        Text("kcal")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    if let firstName, !firstName.isEmpty {
                        Text(firstName + (count > 1 ? " +\(count - 1)" : ""))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 130, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(isEmpty
                            ? NuvyraColors.accent.opacity(0.10)
                            : NuvyraColors.accent.opacity(0.22))
            )
            .shadow(color: NuvyraShadow.card(scheme), radius: 8, x: 0, y: 4)
            .scaleEffect(pressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.title), \(isEmpty ? "boş" : "\(totalCalories) kalori, \(count) öğe")")
    }
}

#if DEBUG
#Preview {
    DashboardMealsStrip(
        meals: [],
        onSelect: { _ in },
        onSeeAll: {}
    )
    .padding()
    .background(NuvyraBackground())
}
#endif
