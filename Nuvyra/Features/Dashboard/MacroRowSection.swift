import SwiftUI

struct MacroRowSection: View {
    var macros: [MacroSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Makrolar", subtitle: "Protein, karbonhidrat ve yağ ritmin.")
            HStack(spacing: NuvyraSpacing.sm) {
                ForEach(macros) { macro in
                    MacroCardItem(macro: macro)
                }
            }
        }
    }
}

private struct MacroCardItem: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var macro: MacroSummary
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: macro.kind.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(macro.tint(scheme: scheme))
                Text(macro.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(macro.consumedGrams))")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .contentTransition(.numericText(value: macro.consumedGrams))
                Text("/ \(Int(macro.targetGrams))g")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(macro.tint(scheme: scheme).opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [macro.tint(scheme: scheme), macro.tint(scheme: scheme).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: proxy.size.width * animatedProgress)
                        .shadow(color: macro.tint(scheme: scheme).opacity(0.35), radius: 6, x: 0, y: 2)
                }
            }
            .frame(height: 8)
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(macro.tint(scheme: scheme).opacity(0.16))
        )
        .onAppear { animate() }
        .onChange(of: macro.progress) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(macro.kind.title) \(Int(macro.consumedGrams)) gram, hedef \(Int(macro.targetGrams)) gram")
    }

    private func animate() {
        if reduceMotion {
            animatedProgress = macro.progress
        } else {
            withAnimation(.easeOut(duration: 0.7)) { animatedProgress = macro.progress }
        }
    }
}

#if DEBUG
#Preview {
    MacroRowSection(macros: DashboardMockPreviewData.macros)
        .padding()
        .background(NuvyraBackground())
}
#endif
