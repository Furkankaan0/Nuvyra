import SwiftUI

/// Numeric input pill used in the Add-Food sheet. Renders an icon, a leading label and
/// an inline `TextField` with a unit suffix on the trailing side.
struct NutritionInputField: View {
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    var icon: String
    var title: String
    var unit: String
    var tint: Color = NuvyraColors.accent
    @Binding var value: Double
    var allowsFraction: Bool = true
    var range: ClosedRange<Double> = 0...9_999

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    TextField("0", value: $value, format: numberFormat)
                        .keyboardType(allowsFraction ? .decimalPad : .numberPad)
                        .focused($focused)
                        .font(.headline.weight(.heavy))
                        .submitLabel(.done)
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Stepper("", value: $value, in: range, step: allowsFraction ? 0.5 : 1)
                .labelsHidden()
        }
        .padding(.horizontal, NuvyraSpacing.md)
        .padding(.vertical, NuvyraSpacing.sm)
        .background(NuvyraColors.card(scheme).opacity(0.7), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(focused ? tint.opacity(0.55) : tint.opacity(0.12), lineWidth: focused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.18), value: focused)
    }

    private var numberFormat: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(allowsFraction ? 0...1 : 0...0))
    }
}

#if DEBUG
private struct NutritionInputFieldPreview: View {
    @State private var grams: Double = 120
    @State private var protein: Double = 24
    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: NuvyraSpacing.sm) {
                NutritionInputField(icon: "scalemass", title: "Miktar", unit: "g", value: $grams, range: 0...2_000)
                NutritionInputField(icon: "bolt.heart", title: "Protein", unit: "g", value: $protein)
            }
            .padding()
        }
    }
}

#Preview {
    NutritionInputFieldPreview()
}
#endif
