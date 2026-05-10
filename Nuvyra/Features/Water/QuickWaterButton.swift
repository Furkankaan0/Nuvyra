import SwiftUI

struct QuickWaterButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var amountMl: Int
    var systemImage: String
    var action: () -> Void
    @State private var pressed = false

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .shadow(color: tint.opacity(0.35), radius: 8, x: 0, y: 4)
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text("+\(amountMl) ml")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(tint.opacity(0.18))
            )
            .scaleEffect(pressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = false }
                }
        )
        .accessibilityLabel("\(amountMl) mililitre su ekle")
    }
}

#if DEBUG
#Preview {
    HStack {
        QuickWaterButton(amountMl: 200, systemImage: "drop", action: {})
        QuickWaterButton(amountMl: 300, systemImage: "drop.fill", action: {})
        QuickWaterButton(amountMl: 500, systemImage: "drop.triangle.fill", action: {})
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
