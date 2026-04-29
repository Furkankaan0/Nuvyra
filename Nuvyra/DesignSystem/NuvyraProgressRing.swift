import SwiftUI

struct NuvyraProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    var lineWidth: CGFloat = 14
    var center: String
    var caption: String

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle().stroke(NuvyraColors.accent.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(colors: [NuvyraColors.accent, NuvyraColors.paleLime, NuvyraColors.accent], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: clamped)
            VStack(spacing: 2) {
                Text(center).font(.system(size: 28, weight: .heavy, design: .rounded))
                Text(caption).font(NuvyraTypography.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("İlerleme yüzde \(Int(clamped * 100))")
    }
}
