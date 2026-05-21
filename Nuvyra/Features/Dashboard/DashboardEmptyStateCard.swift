import SwiftUI

struct DashboardEmptyStateCard: View {
    @Environment(\.colorScheme) private var scheme
    var onAddMeal: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .fill(NuvyraColors.accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "leaf.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                Text("Güne sıfırdan başlıyorsun")
                    .font(NuvyraTypography.section)
                Text("İlk öğününü ekleyerek bugünün ritmini görmeye başla. Su ve adım verilerin geldikçe panelin canlanır.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                NuvyraPrimaryButton(title: "İlk öğünü ekle", systemImage: "plus.circle.fill", action: onAddMeal)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    DashboardEmptyStateCard(onAddMeal: {})
        .padding()
        .background(NuvyraBackground())
}
#endif
