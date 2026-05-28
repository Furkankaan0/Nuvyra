import SwiftUI

/// NOVA grubu 1-4 — işlenmemişten ultra işlenmişe. Dot grafik kullanıcıya
/// numerik değeri okuma külfeti yüklemeden bilgiyi geçer.
struct NovaGroupBadge: View {
    let group: NovaGroup

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(1...4, id: \.self) { tier in
                    Circle()
                        .fill(tier <= group.rawValue ? tint : tint.opacity(0.18))
                        .frame(width: 7, height: 7)
                }
            }
            Text(group.displayLabelTR)
                .font(NuvyraTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("NOVA işlenme grubu")
        .accessibilityValue("\(group.rawValue) — \(group.displayLabelTR)")
    }

    private var tint: Color {
        switch group {
        case .unprocessed: Color(red: 0.13, green: 0.60, blue: 0.32)
        case .processedIngredient: Color(red: 0.46, green: 0.74, blue: 0.32)
        case .processed: Color(red: 0.92, green: 0.62, blue: 0.20)
        case .ultraProcessed: Color(red: 0.85, green: 0.30, blue: 0.25)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        ForEach(NovaGroup.allCases, id: \.self) { group in
            NovaGroupBadge(group: group)
        }
    }
    .padding()
}
