import SwiftUI

/// Wheel-picker step reused by `age`, `height` and `weight` to gather a single
/// integer value. Caller supplies all the copy + range + unit so the same view
/// covers three different onboarding questions.
struct NumberPickerStep: View {
    @Environment(\.colorScheme) private var scheme
    let eyebrow: String
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let symbol: String

    var body: some View {
        PremiumQuestionLayout(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.lg) {
                    HStack {
                        Image(systemName: symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(NuvyraColors.accent, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(value)")
                                .font(.system(size: 52, weight: .heavy, design: .rounded))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                                .contentTransition(.numericText())
                            Text(unit)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }

                    Picker(title, selection: $value) {
                        ForEach(Array(range), id: \.self) { item in
                            Text("\(item) \(unit)").tag(item)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 154)
                    .clipped()
                    .accessibilityLabel(title)

                    RulerHint()
                }
            }
        }
    }
}
