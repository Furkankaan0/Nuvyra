import SwiftUI

struct GoalWeightStep: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var usesGoalWeight: Bool
    @Binding var targetWeightKg: Int
    let currentWeightKg: Int

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Opsiyonel",
            title: "Hedef kilo eklemek ister misin?",
            subtitle: "Bu alan zorunlu değil. Nuvyra hedefi baskı unsuru değil, yön işareti olarak kullanır."
        ) {
            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hedef kilo")
                                .font(NuvyraTypography.section)
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("İstersen atla; günlük hedeflerin yine kişiselleştirilir.")
                                .font(NuvyraTypography.body)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Hedef kilo kullan", isOn: $usesGoalWeight)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }

                    if usesGoalWeight {
                        VStack(spacing: NuvyraSpacing.md) {
                            Text("\(targetWeightKg) kg")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                                .contentTransition(.numericText())

                            Picker("Hedef kilo", selection: $targetWeightKg) {
                                ForEach(35...220, id: \.self) { item in
                                    Text("\(item) kg").tag(item)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 136)
                            .clipped()
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        SoftNoticeCard(
                            title: "Bunu sonra da ekleyebilirsin.",
                            subtitle: "Şimdilik \(currentWeightKg) kg üzerinden kalori, makro, su ve adım hedefi oluşturacağız.",
                            symbol: "sparkle.magnifyingglass"
                        )
                    }
                }
            }
        }
        .onChange(of: usesGoalWeight) { _, isEnabled in
            if isEnabled {
                targetWeightKg = currentWeightKg
            }
        }
    }
}
