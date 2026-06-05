import SwiftUI

/// Shimmer-based loading skeletons. Three pieces:
///
/// - **`.nuvyraSkeleton(isActive:)`** modifier: applies a softly looping
///   highlight gradient to any view's silhouette so the user reads it
///   as "this card is being filled in".
/// - **`NuvyraSkeletonBlock`** primitive: a rounded rectangle in the
///   same colour family the rest of the design system uses, ready to
///   be composed inside a glass card.
/// - **`NuvyraCardSkeleton`** preset: the dashboard / analytics hero
///   card layout pre-built — header line + body lines + footer chips —
///   so loading states match the eventual content shape instead of
///   showing a generic spinner.
///
/// The shimmer is a single `LinearGradient` rotated about the X axis
/// and translated via a `TimelineView`-driven phase. ReduceMotion
/// freezes the gradient at neutral so the silhouette still reads but
/// nothing moves.

// MARK: - Skeleton modifier

private struct NuvyraSkeletonModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    var isActive: Bool

    func body(content: Content) -> some View {
        if !isActive {
            content
        } else if reduceMotion {
            content
                .overlay(staticHighlight.allowsHitTesting(false))
                .accessibilityHidden(true)
        } else {
            content
                .overlay(shimmerOverlay)
                .accessibilityHidden(true)
        }
    }

    /// Frozen frame for reduce-motion. We still show the silhouette so
    /// the user knows something is loading, just without the sweep.
    private var staticHighlight: some View {
        LinearGradient(
            colors: [Color.white.opacity(0), Color.white.opacity(scheme == .dark ? 0.06 : 0.20), Color.white.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.softLight)
    }

    /// 1.4 s sweep — slow enough to read as "calm progress" instead of
    /// the agitated WhatsApp shimmer most apps ship. Two paths share
    /// the same timeline:
    ///   - iOS 18+ — `MeshGradient` whose horizontal control points
    ///     pulse along with the cycle, producing a soft "liquid gradient"
    ///     pull instead of a single travelling band.
    ///   - iOS 17 — the original LinearGradient sweep, kept verbatim
    ///     so the deployment target stays at iOS 17 without spilling
    ///     into the host's silhouette.
    @ViewBuilder
    private var shimmerOverlay: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
            let cycle = 1.4
            let raw = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            let phase = CGFloat(raw)

            if #available(iOS 18.0, *) {
                meshShimmer(phase: phase)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            } else {
                linearShimmer(phase: phase)
            }
        }
    }

    /// iOS 17 fallback — original 3-stop LinearGradient that slides
    /// horizontally across the host shape. Calm and cheap.
    private func linearShimmer(phase: CGFloat) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(scheme == .dark ? 0.14 : 0.40),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5)
            .offset(x: -width * 0.75 + (width * 1.5) * phase)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    /// iOS 18+ mesh-driven shimmer. A 3×2 lattice keeps the cost
    /// modest while still giving the highlight a fluid pulled feel as
    /// the middle row's X coordinates breathe along with `phase`.
    @available(iOS 18.0, *)
    @ViewBuilder
    private func meshShimmer(phase: CGFloat) -> some View {
        let pulse = sin(phase * .pi * 2) * 0.10  // ±0.10 lateral breath
        let highlight = scheme == .dark ? 0.18 : 0.45
        MeshGradient(
            width: 3,
            height: 2,
            points: [
                SIMD2(0.0, 0.0), SIMD2(0.5 + Float(pulse), 0.0), SIMD2(1.0, 0.0),
                SIMD2(0.0, 1.0), SIMD2(0.5 - Float(pulse), 1.0), SIMD2(1.0, 1.0)
            ],
            colors: [
                Color.white.opacity(0), Color.white.opacity(highlight), Color.white.opacity(0),
                Color.white.opacity(0), Color.white.opacity(highlight * 0.65), Color.white.opacity(0)
            ]
        )
    }
}

extension View {
    /// Wraps the receiver with the brand shimmer. When `isActive` is
    /// `false` the modifier is a no-op so call sites can leave it on
    /// permanent state-driven views without paying any cost.
    func nuvyraSkeleton(isActive: Bool = true) -> some View {
        modifier(NuvyraSkeletonModifier(isActive: isActive))
    }
}

// MARK: - Skeleton block

/// Building-block placeholder that reads as "a line of text" or "a
/// metric value about to arrive". Pre-tinted with the card colour so
/// the shimmer doesn't need to fight a transparent surface.
struct NuvyraSkeletonBlock: View {
    @Environment(\.colorScheme) private var scheme
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(NuvyraColors.mutedGray.opacity(scheme == .dark ? 0.22 : 0.18))
            .frame(maxWidth: width, alignment: .leading)
            .frame(height: height)
            .nuvyraSkeleton()
    }
}

// MARK: - Card skeleton

/// Pre-composed loading silhouette that matches the shape of a hero
/// glass card so the transition from "loading" to "loaded" doesn't
/// jump the page layout.
struct NuvyraCardSkeleton: View {
    enum Style {
        /// Hero layout — title + subtitle + 4-block metric row.
        case hero
        /// Single metric strip — title + value + caption.
        case strip
    }

    var style: Style = .hero

    var body: some View {
        NuvyraGlassCard(.prominent) {
            switch style {
            case .hero: heroLayout
            case .strip: stripLayout
            }
        }
    }

    private var heroLayout: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    NuvyraSkeletonBlock(width: 140, height: 18)
                    NuvyraSkeletonBlock(width: 90, height: 12)
                }
                Spacer()
                Circle()
                    .fill(NuvyraColors.mutedGray.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .nuvyraSkeleton()
            }
            HStack(spacing: NuvyraSpacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        NuvyraSkeletonBlock(height: 10)
                        NuvyraSkeletonBlock(width: 60, height: 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(NuvyraSpacing.sm)
                    .background(NuvyraColors.mutedGray.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
                }
            }
        }
    }

    private var stripLayout: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Circle()
                .fill(NuvyraColors.mutedGray.opacity(0.2))
                .frame(width: 44, height: 44)
                .nuvyraSkeleton()
            VStack(alignment: .leading, spacing: 6) {
                NuvyraSkeletonBlock(width: 120, height: 14)
                NuvyraSkeletonBlock(width: 200, height: 11)
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Skeletons") {
    ZStack {
        NuvyraBackground(.animated)
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                NuvyraCardSkeleton(style: .hero)
                NuvyraCardSkeleton(style: .strip)
                NuvyraCardSkeleton(style: .strip)
            }
            .padding()
        }
    }
}
#endif
