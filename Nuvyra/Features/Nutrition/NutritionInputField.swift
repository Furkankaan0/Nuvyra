import SwiftUI

struct NutritionInputField: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var systemImage: String
    var unitSuffix: String
    var tint: Color
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...500
    var step: Double = 1

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .textCase(.uppercase)
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    let newValue = max(range.lowerBound, value - step)
                    value = newValue
                } label: {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(tint)
                        .background(tint.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) azalt")

                TextField("", value: $value, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)

                Text(unitSuffix)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                Button {
                    let newValue = min(range.upperBound, value + step)
                    value = newValue
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.white)
                        .background(tint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) artır")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(NuvyraColors.card(scheme).opacity(0.85), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(focused ? tint : tint.opacity(0.18), lineWidth: focused ? 1.4 : 1)
            )
        }
    }
}

#if DEBUG
private struct NutritionInputFieldPreview: View {
    @State private var value: Double = 120
    var body: some View {
        NutritionInputField(title: "Protein", systemImage: "bolt.heart", unitSuffix: "g", tint: NuvyraColors.mutedCoral, value: $value)
            .padding()
            .background(NuvyraBackground())
    }
}

#Preview { NutritionInputFieldPreview() }
#endif
