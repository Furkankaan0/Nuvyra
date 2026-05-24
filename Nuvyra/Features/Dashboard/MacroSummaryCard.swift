import SwiftUI

struct MacroSummaryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var macros: [MacroSummary]

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Makrolar", subtitle: "Protein • Karbonhidrat • Yağ")
                HStack(spacing: NuvyraSpacing.md) {
                    ForEach(macros) { macro in
                        MacroDial(macro: macro)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MacroDial: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var macro: MacroSummary
    @State private var animated: Double = 0

    private var tint: Color {
        switch macro.kind {
        case .protein: NuvyraColors.mutedCoral
        case .carbs: NuvyraColors.paleLime
        case .fat: NuvyraColors.softSand
        }
    }

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            ZStack {
                Circle().stroke(tint.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: animated)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.4), radius: 6, x: 0, y: 3)
                VStack(spacing: 0) {
                    Image(systemName: macro.kind.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(macro.kind.shortTitle)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
            }
            .frame(width: 78, height: 78)

            VStack(spacing: 2) {
                Text(macro.kind.title)
                    .font(NuvyraTypography.caption.weight(.semibold))
                Text(macro.displayValue)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { animate() }
        .onChange(of: macro.progress) { _, _ in animate() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(macro.kind.title): \(macro.displayValue), yüzde \(Int(macro.progress * 100))")
    }

    private func animate() {
        guard !reduceMotion else { animated = macro.progress; return }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { animated = macro.progress }
    }
}

#if DEBUG
#Preview("Macros") {
    ZStack {
        NuvyraBackground()
        MacroSummaryCard(macros: DashboardPreviewData.macros).padding()
    }
}
#endif
