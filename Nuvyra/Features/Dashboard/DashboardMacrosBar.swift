import SwiftUI

struct DashboardMacrosBar: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var macros: [MacroSummary]
    @State private var animated: Bool = false

    private var totalConsumed: Double {
        macros.reduce(0) { $0 + $1.consumedGrams }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Makrolar")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Spacer()
                Text("\(Int(totalConsumed)) g")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(NuvyraColors.accent.opacity(0.10), in: Capsule())
            }

            stackedBar
                .frame(height: 12)

            HStack(spacing: NuvyraSpacing.md) {
                ForEach(macros) { macro in
                    legendItem(macro: macro)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.05 : 0.32))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 14, x: 0, y: 8)
        .onAppear {
            if reduceMotion { animated = true } else {
                withAnimation(.easeOut(duration: 0.7)) { animated = true }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Makrolar. " + macros.map { "\($0.kind.title) \(Int($0.consumedGrams)) gram, hedef \(Int($0.targetGrams))" }.joined(separator: ", "))
    }

    @ViewBuilder
    private var stackedBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(macros) { macro in
                    let segmentWidth = proxy.size.width * weight(for: macro)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [macro.tint(scheme: scheme), macro.tint(scheme: scheme).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animated ? segmentWidth : 0)
                        .shadow(color: macro.tint(scheme: scheme).opacity(0.32), radius: 4, x: 0, y: 2)
                }
                Spacer(minLength: 0)
            }
            .background(
                Capsule()
                    .fill(NuvyraColors.accent.opacity(0.08))
            )
            .clipShape(Capsule())
        }
    }

    private func weight(for macro: MacroSummary) -> Double {
        guard macro.targetGrams > 0 else { return 0 }
        // Each macro shown proportional to its own target (so a 120g protein and 210g carb don't both fill 100% the same way).
        let allTargets = macros.reduce(0.0) { $0 + $1.targetGrams }
        guard allTargets > 0 else { return 0 }
        let allowedShare = macro.targetGrams / allTargets
        let progress = min(macro.consumedGrams / macro.targetGrams, 1.0)
        return allowedShare * progress
    }

    private func legendItem(macro: MacroSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(macro.tint(scheme: scheme))
                    .frame(width: 8, height: 8)
                Text(macro.kind.title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(macro.consumedGrams))")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .contentTransition(.numericText(value: macro.consumedGrams))
                Text("/\(Int(macro.targetGrams))g")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    DashboardMacrosBar(macros: DashboardMockPreviewData.macros)
        .padding()
        .background(NuvyraBackground())
}
#endif
