import SwiftUI

/// Horizontal paging container that *snaps* each card into the centre of
/// the viewport. Built on iOS 17's `scrollTargetBehavior(.viewAligned)` —
/// the native API does the magnet work for us, we just feed it a layout
/// hint and a per-card width.
///
/// Cards naturally pop forward as they reach the centre line via
/// `scrollTransition`. We use a small 0.92 ↔ 1.0 scale + opacity falloff
/// so off-centre cards read as "next to focus" without disappearing.
///
/// ```swift
/// NuvyraSnapCarousel(items: items, id: \.id, spacing: 12) { item in
///     SomeCard(model: item)
/// }
/// ```
struct NuvyraSnapCarousel<Item: Identifiable, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var items: [Item]
    /// Horizontal padding around each card so the centre snap still has
    /// some breathing room on the edges.
    var contentInset: CGFloat = NuvyraSpacing.lg
    /// Distance between adjacent cards.
    var spacing: CGFloat = NuvyraSpacing.md
    /// Card width as a fraction of the viewport. 0.86 leaves enough side
    /// reveal to show the user "there's more".
    var cardWidthFraction: CGFloat = 0.86
    /// Card height — fixed so SwiftUI doesn't try to size the row to its
    /// tallest card on every snap (visual jank during scroll).
    var cardHeight: CGFloat = 168

    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width * cardWidthFraction - spacing, 220)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: cardWidth, height: cardHeight)
                            .scrollTransition(.interactive) { view, phase in
                                view
                                    .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1.0 : 0.92))
                                    .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1.0 : 0.65))
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, contentInset)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
        .frame(height: cardHeight)
    }
}

#if DEBUG
private struct SnapPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

#Preview {
    let items = [
        SnapPreviewItem(title: "Kalori", value: "1.240", tint: NuvyraColors.mutedCoral),
        SnapPreviewItem(title: "Su", value: "1.4L", tint: NuvyraColors.softMint),
        SnapPreviewItem(title: "Adım", value: "6.420", tint: NuvyraColors.accent),
        SnapPreviewItem(title: "Protein", value: "78 g", tint: NuvyraColors.paleLime)
    ]
    return ZStack {
        NuvyraBackground(.animated)
        VStack(alignment: .leading) {
            Text("Bugünkü öne çıkanlar")
                .font(NuvyraTypography.section)
                .padding(.leading, NuvyraSpacing.lg)
            NuvyraSnapCarousel(items: items) { item in
                NuvyraGlassCard(.prominent) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(item.tint)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }
}
#endif
