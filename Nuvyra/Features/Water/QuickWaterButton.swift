import SwiftUI

/// Pill-shaped quick add button (200 / 300 / 500 ml). Provides a small scale-on-press
/// animation and respects Reduce Motion.
struct QuickWaterButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var amountMl: Int
    var tint: Color = Color(red: 0.20, green: 0.56, blue: 0.95)
    var action: () -> Void

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
                    pressed = false
                }
                action()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.headline.weight(.bold))
                Text("+\(amountMl)")
                    .font(.subheadline.weight(.heavy))
                Text("ml")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(amountMl) ml su ekle")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        HStack {
            QuickWaterButton(amountMl: 200) {}
            QuickWaterButton(amountMl: 300) {}
            QuickWaterButton(amountMl: 500) {}
        }
        .padding()
    }
}
#endif
