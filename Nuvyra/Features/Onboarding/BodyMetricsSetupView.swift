import SwiftUI

/// Onboarding step that collects gender / age / height / weight so the
/// calorie + water targets can be calculated with Mifflin-St Jeor instead
/// of being shown as fixed numbers.
struct BodyMetricsSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                NuvyraSectionHeader(
                    title: "Vücut bilgilerin",
                    subtitle: "Bu değerler cihazında kalır ve günlük hedefini hesaplamak için kullanılır."
                )

                genderSelector
                ageStepper
                heightStepper
                weightStepper
            }
        }
    }

    // MARK: - Gender

    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Cinsiyet")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))

            VStack(spacing: NuvyraSpacing.xs) {
                ForEach(Gender.allCases) { gender in
                    GenderOptionRow(
                        gender: gender,
                        isSelected: viewModel.gender == gender
                    ) {
                        viewModel.gender = gender
                    }
                }
            }
        }
    }

    // MARK: - Steppers

    private var ageStepper: some View {
        MetricStepperRow(
            title: "Yaş",
            unit: "yıl",
            value: Binding(
                get: { Double(viewModel.age ?? 30) },
                set: { viewModel.age = Int($0) }
            ),
            range: 15...100,
            step: 1,
            placeholder: viewModel.age == nil ? "Yaşını seç" : nil,
            displayValue: viewModel.age.map { "\($0)" }
        )
    }

    private var heightStepper: some View {
        MetricStepperRow(
            title: "Boy",
            unit: "cm",
            value: Binding(
                get: { viewModel.heightCm ?? 170 },
                set: { viewModel.heightCm = $0 }
            ),
            range: 120...230,
            step: 1,
            placeholder: viewModel.heightCm == nil ? "Boyunu seç" : nil,
            displayValue: viewModel.heightCm.map { String(format: "%.0f", $0) }
        )
    }

    private var weightStepper: some View {
        MetricStepperRow(
            title: "Kilo",
            unit: "kg",
            value: Binding(
                get: { viewModel.weightKg ?? 70 },
                set: { viewModel.weightKg = $0 }
            ),
            range: 35...250,
            step: 0.5,
            placeholder: viewModel.weightKg == nil ? "Kilonu seç" : nil,
            displayValue: viewModel.weightKg.map { String(format: "%.1f", $0) }
        )
    }
}

private struct GenderOptionRow: View {
    @Environment(\.colorScheme) private var scheme
    var gender: Gender
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.12), in: Circle())

                Text(gender.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Spacer(minLength: NuvyraSpacing.sm)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.52))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected ? NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.12) : NuvyraColors.card(scheme).opacity(0.58),
                in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.42) : Color.white.opacity(scheme == .dark ? 0.08 : 0.32))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gender.title)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }

    private var symbol: String {
        switch gender {
        case .female: "person.fill"
        case .male: "person.fill"
        case .other: "person.fill"
        case .preferNotToSay: "questionmark.circle.fill"
        }
    }
}

private struct MetricStepperRow: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var unit: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var placeholder: String?
    var displayValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                Spacer()
                if let displayValue {
                    Text("\(displayValue) \(unit)")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                } else if let placeholder {
                    Text(placeholder)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme).opacity(0.6))
                }
            }

            HStack(spacing: NuvyraSpacing.sm) {
                stepperButton(systemImage: "minus") {
                    value = max(range.lowerBound, value - step)
                }
                Slider(value: $value, in: range, step: step)
                    .tint(NuvyraColors.accent)
                stepperButton(systemImage: "plus") {
                    value = min(range.upperBound, value + step)
                }
            }
        }
        .padding(14)
        .background(NuvyraColors.card(scheme).opacity(0.58), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.32))
        )
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 34, height: 34)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
