import SwiftUI

/// Material-backed card with a tiered visual hierarchy. iOS 26 ships a
/// native `.glassEffect()` modifier, but Nuvyra still targets iOS 17 so we
/// approximate that look with `ultraThinMaterial` + a specular highlight +
/// a gradient stroke + a multi-layer drop shadow.
///
/// Variants:
/// - `.regular` — section / content cards. Default; matches the original
///   `NuvyraGlassCard` look so the migration is a no-op for existing
///   call sites.
/// - `.prominent` — hero cards that should pull the eye first
///   (CalorieBalanceCard, EnergyBalanceCard, WeeklyComparisonCard,
///   MealTimingCard, WeightTrendCard). Adds a brand-tinted glass fill and
///   a deeper, two-layer shadow.
/// - `.floating` — sheets, modal pickers, FAB-style elements. Thicker
///   material + strongest shadow tier.
struct NuvyraGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var variant: Variant
    let content: Content

    enum Variant {
        case regular
        case prominent
        case floating
    }

    init(_ variant: Variant = .regular, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        content
            .padding(NuvyraSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(materialBackground)
            .background(stabilizingFillLayer)
            .background(prominentTintLayer)
            .clipShape(shape)
            .overlay(strokeOverlay)
            .overlay(specularOverlay)
            .nuvyraShadow(shadowTier, scheme: scheme)
    }

    // MARK: - Layers

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
    }

    /// The system material does the heavy lifting — `.ultraThin` reads as
    /// a glass for regular/prominent; `.thin` for floating gives the modal
    /// surface a touch more opacity so its hierarchy beats the page below.
    @ViewBuilder
    private var materialBackground: some View {
        switch variant {
        case .regular, .prominent:
            shape.fill(.ultraThinMaterial)
        case .floating:
            shape.fill(.thinMaterial)
        }
    }

    /// Neutral fill sitting behind the material. Without this, scrolling a
    /// glass card over the animated green/mint background lets the system
    /// material sample too much backdrop and the whole card flashes green.
    private var stabilizingFillLayer: some View {
        shape.fill(NuvyraColors.card(scheme).opacity(stabilizingOpacity))
    }

    private var stabilizingOpacity: Double {
        switch (variant, scheme) {
        case (.floating, .dark): return 0.86
        case (.floating, .light): return 0.92
        case (_, .dark): return 0.74
        case (_, .light): return 0.84
        @unknown default: return 0.84
        }
    }

    /// Brand-tinted wash painted *behind* the material. Light scheme picks
    /// up a subtle warm veil instead of the green accent so scroll-time
    /// material compositing never turns dashboard widgets mint.
    @ViewBuilder
    private var prominentTintLayer: some View {
        if variant == .prominent {
            shape.fill(NuvyraColors.prominentGlassTint(scheme))
        }
    }

    /// Gradient stroke — runs brighter at the top edge to read as a light
    /// catch. The width difference between variants is deliberate; a
    /// thicker hairline pulls the eye, so prominent cards win.
    private var strokeOverlay: some View {
        shape.stroke(NuvyraColors.glassStroke(scheme), lineWidth: strokeWidth)
    }

    private var strokeWidth: CGFloat {
        switch variant {
        case .regular: return 0.6
        case .prominent: return 1.0
        case .floating: return 0.8
        }
    }

    /// Top-edge highlight that lifts the card off the page. We mask a
    /// narrow gradient to the card's rounded shape so the highlight
    /// follows the corners instead of clipping flat.
    private var specularOverlay: some View {
        shape
            .strokeBorder(NuvyraColors.specularHighlight(scheme), lineWidth: 1)
            .mask(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }

    private var shadowTier: NuvyraShadow.Elevation {
        switch variant {
        case .regular: return .soft
        case .prominent: return .elevated
        case .floating: return .floating
        }
    }
}

#if DEBUG
#Preview("Glass tiers") {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                NuvyraGlassCard {
                    Text("Regular — sections + content").font(.headline)
                }
                NuvyraGlassCard(.prominent) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prominent — hero cards").font(.headline)
                        Text("Adım ortalaman geçen haftadan %18 yüksek.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                NuvyraGlassCard(.floating) {
                    Text("Floating — modals & sheets").font(.headline)
                }
            }
            .padding()
        }
    }
}
#endif
