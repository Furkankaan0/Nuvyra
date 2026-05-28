import SwiftUI

/// Yatay scroll'lu alerjen pill listesi. Boş array verilirse hiç çizmez —
/// caller `isEmpty` kontrolü yapmak zorunda kalmaz.
struct AllergenPillRow: View {
    let allergens: [Allergen]

    var body: some View {
        if !allergens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allergens) { allergen in
                        AllergenPill(allergen: allergen)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct AllergenPill: View {
    let allergen: Allergen

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(allergen.displayLabelTR)
                .font(NuvyraTypography.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(NuvyraColors.mutedCoral)
        .background(
            Capsule(style: .continuous)
                .fill(NuvyraColors.mutedCoral.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(NuvyraColors.mutedCoral.opacity(0.30), lineWidth: 0.8)
        )
        .accessibilityLabel("Alerjen: \(allergen.displayLabelTR)")
    }
}

#Preview {
    AllergenPillRow(allergens: [.gluten, .dairy, .peanut, .treeNut, .sesame, .egg])
        .padding()
}
