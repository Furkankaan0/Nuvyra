import SwiftUI

/// Compact pill telling the user where a `FoodItem`'s nutrition data came from.
/// Tappable via the `accessibilityHint` to expose verbose source info.
struct SourceChip: View {
    let source: ProductSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(source.displayLabel)
                .font(NuvyraTypography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .accessibilityElement()
        .accessibilityLabel("Veri kaynağı")
        .accessibilityValue(source.displayLabel)
    }

    private var symbolName: String {
        switch source {
        case .openFoodFacts: "globe.europe.africa.fill"
        case .usda: "leaf.fill"
        case .fatSecret: "checkmark.seal.fill"
        case .cache: "internaldrive.fill"
        case .manual: "pencil.and.outline"
        case .estimated: "wand.and.stars.inverse"
        }
    }

    private var tint: Color {
        switch source {
        case .openFoodFacts: Color(red: 0.20, green: 0.55, blue: 0.85)
        case .usda: NuvyraColors.accent
        case .fatSecret: Color(red: 0.55, green: 0.40, blue: 0.85)
        case .cache: NuvyraColors.mutedGray
        case .manual: Color(red: 0.95, green: 0.60, blue: 0.20)
        case .estimated: Color(red: 0.85, green: 0.55, blue: 0.55)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(ProductSource.allCases, id: \.self) { source in
            SourceChip(source: source)
        }
    }
    .padding()
}
