import SwiftUI

/// Re-usable visual scaffold for first-run / empty / mid-flow placeholder
/// states. Three layers:
///
/// 1. An **illustrated medallion** — a soft accent-tinted halo with a
///    gentle outward pulse (suppressed under `accessibilityReduceMotion`)
///    holding a single SF Symbol painted with the accent gradient.
/// 2. A **headline + body** stack with calm-coach phrasing.
/// 3. A **glass pill bullet rail** that previews what the user can do.
///
/// Doesn't pick a card surface itself — sits inside a `NuvyraGlassCard`
/// (or any other container) the caller chose, so the same placeholder
/// scaffold works on hero glass, sheet glass and inline cards.
struct NuvyraIllustratedPlaceholder<Actions: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var systemImage: String
    var title: String
    var subtitle: String
    var tint: Color = NuvyraColors.accent
    /// Optional 1–4 short bullet strings rendered as glass pills below the
    /// headline. Hidden when the array is empty.
    var bullets: [String] = []
    @ViewBuilder var actions: () -> Actions

    init(
        systemImage: String,
        title: String,
        subtitle: String,
        tint: Color = NuvyraColors.accent,
        bullets: [String] = [],
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.bullets = bullets
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            HStack(alignment: .center, spacing: NuvyraSpacing.md) {
                medallion
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NuvyraTypography.section)
                    Text(subtitle)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !bullets.isEmpty {
                FlowLayout(spacing: NuvyraSpacing.xs) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        NuvyraGlassPill(systemImage: "sparkles", title: bullet, tint: tint)
                    }
                }
            }

            actions()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            // Outer pulse halo — gives the empty state a subtle "alive" feel.
            Circle()
                .fill(tint.opacity(scheme == .dark ? 0.16 : 0.20))
                .frame(width: 76, height: 76)
                .scaleEffect(pulse ? 1.08 : 0.96)
                .blur(radius: 0.5)
                .opacity(0.6)

            // Inner glass disc.
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .fill(tint.opacity(scheme == .dark ? 0.22 : 0.16))
                )
                .overlay(
                    Circle()
                        .stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.7)
                )

            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: 76, height: 76)
        .nuvyraShadow(.ambient, scheme: scheme)
    }
}

// MARK: - Tiny flow layout (used for bullet pill wrapping)

/// Compact wrapping HStack — `LazyVGrid` over-allocates the row when one
/// pill is very short, and `ViewThatFits` flips abruptly. A custom
/// `Layout` keeps the wrap natural across locales (TR pills tend to be
/// longer than EN).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLine: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                maxLine = max(maxLine, lineWidth - spacing)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        maxLine = max(maxLine, lineWidth - spacing)
        return CGSize(width: maxLine, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Placeholder examples") {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                NuvyraGlassCard(.prominent) {
                    NuvyraIllustratedPlaceholder(
                        systemImage: "sparkles",
                        title: "Güne başla",
                        subtitle: "İlk kaydını ekle ki ritmin oluşmaya başlasın.",
                        bullets: ["Bir öğün", "1 bardak su", "10 dk yürüyüş"]
                    ) {
                        HStack {
                            NuvyraPrimaryButton(title: "Öğün ekle", systemImage: "fork.knife", action: {})
                            NuvyraSecondaryButton(title: "+250 ml", systemImage: "drop", action: {})
                        }
                    }
                }
                NuvyraGlassCard {
                    NuvyraIllustratedPlaceholder(
                        systemImage: "wifi.exclamationmark",
                        title: "Bağlantı yok",
                        subtitle: "İnternet bağlantını kontrol edip tekrar dene.",
                        tint: NuvyraColors.mutedCoral,
                        bullets: []
                    ) {
                        NuvyraSecondaryButton(title: "Tekrar dene", systemImage: "arrow.clockwise", action: {})
                    }
                }
            }
            .padding()
        }
    }
}
#endif
