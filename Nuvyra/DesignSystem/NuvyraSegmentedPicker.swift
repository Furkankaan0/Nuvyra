import SwiftUI

/// Glass-tinted segmented picker. Drop-in replacement for SwiftUI's
/// native `Picker(.segmented)` whenever the design needs to match the
/// rest of the Liquid Glass family — the system control's metal
/// background fights the brand palette.
///
/// The selected pill slides between segments using `matchedGeometryEffect`
/// so the indicator reads as one moving object instead of two separate
/// fade-ins. ReduceMotion shortcuts the spring to a flat duration.
///
/// Generic in two axes:
///   - `Selection` — any `Hashable` enum / value type.
///   - `Label` — the view your `optionContent` builder returns. Lets the
///     same picker render plain text labels or SF Symbol-prefixed pills.
///
/// Usage:
///   ```swift
///   NuvyraSegmentedPicker(
///       selection: $period,
///       options: AnalyticsPeriod.allCases
///   ) { period in
///       Text(period.title)
///   }
///   ```
struct NuvyraSegmentedPicker<Selection: Hashable, Label: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    @Binding var selection: Selection
    var options: [Selection]
    @ViewBuilder var optionContent: (Selection) -> Label

    /// Accessibility label per option. Defaults to the SwiftUI auto
    /// label which is usually fine for `Text` content; pass a real
    /// label closure when options carry only symbols.
    var accessibilityLabel: (Selection) -> String = { String(describing: $0) }

    var body: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            ForEach(options, id: \.self) { option in
                Button {
                    select(option)
                } label: {
                    optionContent(option)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(option == selection ? .white : NuvyraColors.primaryText(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Capsule())
                        .background(selectionPill(for: option))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(option))
                .accessibilityValue(option == selection ? "Seçili" : "Seçili değil")
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.7))
        .overlay(
            Capsule()
                .strokeBorder(NuvyraColors.specularHighlight(scheme), lineWidth: 1)
                .mask(LinearGradient(colors: [Color.black, Color.black.opacity(0)], startPoint: .top, endPoint: .center))
                .allowsHitTesting(false)
        )
        .nuvyraShadow(.ambient, scheme: scheme)
    }

    /// `matchedGeometryEffect` paints the selected pill as a single
    /// view that slides between segments instead of two separate
    /// crossfades. The unselected branch returns a clear pill in the
    /// same namespace so the layout reserves the same space.
    @ViewBuilder
    private func selectionPill(for option: Selection) -> some View {
        if option == selection {
            Capsule()
                .fill(NuvyraColors.accentGradient)
                .matchedGeometryEffect(id: "nuvyra.segmented.indicator", in: namespace)
                .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 8, x: 0, y: 4)
        } else {
            Capsule().fill(Color.clear)
        }
    }

    private func select(_ option: Selection) {
        let animation: Animation = reduceMotion
            ? .linear(duration: 0.18)
            : .spring(response: 0.36, dampingFraction: 0.78)
        withAnimation(animation) {
            selection = option
        }
    }
}

#if DEBUG
private enum DemoPeriod: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: "Günlük"
        case .weekly: "Haftalık"
        case .monthly: "Aylık"
        }
    }
}

#Preview {
    struct DemoView: View {
        @State private var selection: DemoPeriod = .weekly
        var body: some View {
            ZStack {
                NuvyraBackground(.animated)
                VStack(spacing: NuvyraSpacing.xl) {
                    NuvyraSegmentedPicker(
                        selection: $selection,
                        options: DemoPeriod.allCases
                    ) { period in
                        Text(period.title)
                    }
                    Text("Şu an: \(selection.title)")
                        .font(.headline)
                }
                .padding()
            }
        }
    }
    return DemoView()
}
#endif
