import SwiftUI

/// Nutri-Score (A–E) rozeti — Open Food Facts'in resmi renk paletini sade
/// SwiftUI Capsule'e indirgenmiş hali. A en sağlıklı (koyu yeşil), E en az
/// sağlıklı (kırmızı). Nutri-Score yoksa nil ile sessizce kaybolur.
struct NutriScoreBadge: View {
    let grade: NutriScore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NutriScore.allCases, id: \.self) { letter in
                Text(letter.displayLabel)
                    .font(.system(size: 12, weight: letter == grade ? .heavy : .medium, design: .rounded))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(letter == grade ? .white : color(for: letter).opacity(0.55))
                    .background(
                        Circle()
                            .fill(letter == grade ? color(for: letter) : Color.clear)
                    )
                    .scaleEffect(letter == grade ? 1.18 : 1.0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("Nutri-Score")
        .accessibilityValue(grade.displayLabel)
    }

    private func color(for letter: NutriScore) -> Color {
        switch letter {
        case .a: Color(red: 0.13, green: 0.60, blue: 0.32)
        case .b: Color(red: 0.46, green: 0.74, blue: 0.32)
        case .c: Color(red: 0.95, green: 0.78, blue: 0.20)
        case .d: Color(red: 0.92, green: 0.52, blue: 0.20)
        case .e: Color(red: 0.85, green: 0.25, blue: 0.20)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        ForEach(NutriScore.allCases, id: \.self) { score in
            NutriScoreBadge(grade: score)
        }
    }
    .padding()
}
