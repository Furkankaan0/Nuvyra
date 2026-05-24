import SwiftUI

/// Daily caffeine snapshot with a warning state when the user crosses 400 mg
/// (FDA's commonly cited adult limit; not medical advice).
struct CaffeineCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedRatio: Double = 0

    var totalMg: Double
    var limitMg: Int

    private var ratio: Double { limitMg > 0 ? totalMg / Double(limitMg) : 0 }
    private var isOver: Bool { ratio > 1 }
    private var tint: Color {
        if isOver { return NuvyraColors.mutedCoral }
        if ratio > 0.8 { return NuvyraColors.softSand }
        return Color(red: 0.55, green: 0.35, blue: 0.20)
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                progressBar
                Text(captionText)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                Text("Limit FDA referansıdır; gebelik veya tıbbi durumda bireysel öneri için profesyonel destek al.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { animate() }
        .onChange(of: ratio) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kafein: \(Int(totalMg)) mg / \(limitMg) mg")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kafein")
                    .font(NuvyraTypography.section)
                Text("Bugünkü toplam alım")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(totalMg)) mg")
                .font(.title2.weight(.heavy))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.65)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(min(proxy.size.width * animatedRatio, proxy.size.width), 0))
            }
        }
        .frame(height: 10)
    }

    private var captionText: String {
        if totalMg == 0 {
            return "Henüz kafeinli içecek kaydetmedin."
        }
        if isOver {
            return "Günlük limitin üzerinde — uyku kalitesi için kalan saatlerde su tercih etmek iyi gelir."
        }
        if ratio > 0.8 {
            return "Limite yaklaşıyorsun. Akşam saatlerinde kafeini azaltmak uyku ritmini destekler."
        }
        return "Limit altında. Hatırlatıcı: öğleden sonra kafein uyku düzenini etkileyebilir."
    }

    private func animate() {
        let target = min(max(ratio, 0), 1.2)
        guard !reduceMotion else { animatedRatio = target; return }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) { animatedRatio = target }
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            CaffeineCard(totalMg: 0, limitMg: 400)
            CaffeineCard(totalMg: 220, limitMg: 400)
            CaffeineCard(totalMg: 480, limitMg: 400)
        }
        .padding()
    }
}
#endif
