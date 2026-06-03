import SwiftUI

/// Single-shot, calm-tone confetti. Sits as a `ZStack` overlay above any
/// card and bursts when the `trigger` value changes. Tuned for Nuvyra's
/// "premium calm" voice: ~22 particles, accent-tinted, fall under
/// gravity over ~1.4s, fade to zero before the user has time to read
/// them as noise.
///
/// The whole component is a single `Canvas` + `TimelineView` — no
/// `ForEach(particles)` over a State array, so SwiftUI never has to
/// re-diff 22 sub-views at 60 fps. State of the particle field is held
/// in a small struct; the canvas reads `now` to advance physics.
///
/// `accessibilityReduceMotion` makes the component render nothing —
/// the trigger still fires, but no particles draw. Same opt-out behaviour
/// every other Nuvyra motion primitive ships with.
struct NuvyraConfettiBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var field = ParticleField()

    /// Two particle shapes the canvas can paint.
    /// - `.circles` (default): tiny filled discs in the brand palette.
    /// - `.symbols(...)`: SF Symbols drawn through the canvas's
    ///   `resolveSymbol` so they paint with the symbol's actual glyph
    ///   bitmap — much richer than confetti dots, perfect for the
    ///   AchievementShareCard "celebration" moment.
    enum Style: Equatable {
        case circles
        case symbols([String])
    }

    /// Anything `Equatable & Hashable`; we listen for changes and fire a
    /// burst on every transition. `true ↔ false` works, `Int` counts
    /// work, milestone enums work.
    var trigger: AnyHashable

    /// Palette the particles draw from. Defaults to Nuvyra's hero accents
    /// so the burst always reads as part of the brand instead of "party
    /// from app template".
    var palette: [Color] = [
        NuvyraColors.accent,
        NuvyraColors.softMint,
        NuvyraColors.softSand,
        NuvyraColors.paleLime,
        NuvyraColors.mutedCoral
    ]

    /// Particle style. `.circles` is the default — `.symbols(...)` swaps
    /// in SF Symbol bitmaps and is what AchievementShareCard uses.
    var style: Style = .circles

    /// How long the burst takes to fully fade. Anything past 1.6s starts
    /// to feel like decoration, so 1.4 is the ceiling we tested.
    var duration: Double = 1.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
                guard !reduceMotion else { return }
                let now = context.date.timeIntervalSinceReferenceDate
                let elapsed = now - field.startTime
                guard field.isActive, elapsed >= 0, elapsed < duration else { return }
                drawField(ctx: ctx, size: size, elapsed: elapsed)
            } symbols: {
                // Pre-resolved symbol glyphs. The canvas renders them by
                // index (matches particle.symbolIndex). We always provide
                // the symbol set even in `.circles` mode so SwiftUI
                // doesn't have to rebuild the ViewBuilder on style switch.
                ForEach(Array(symbolPaletteFor(style: style).enumerated()), id: \.offset) { index, name in
                    Image(systemName: name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .tag(index)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            let symbolCount = symbolPaletteFor(style: style).count
            field.fire(
                now: Date().timeIntervalSinceReferenceDate,
                palette: palette,
                symbolCount: symbolCount
            )
        }
    }

    // MARK: - Drawing

    private func drawField(ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let progress = elapsed / duration
        for particle in field.particles {
            let position = particle.position(at: elapsed, in: size)
            let alpha = particle.opacity(at: progress)
            guard alpha > 0.01 else { continue }

            var localCtx = ctx
            localCtx.opacity = alpha

            switch style {
            case .circles:
                let rect = CGRect(
                    x: position.x - particle.radius,
                    y: position.y - particle.radius,
                    width: particle.radius * 2,
                    height: particle.radius * 2
                )
                localCtx.fill(Path(ellipseIn: rect), with: .color(particle.tint))

            case .symbols:
                guard let resolved = ctx.resolveSymbol(id: particle.symbolIndex) else { continue }
                // The canvas resolves symbols at their natural size; we
                // tint by shading the canvas before drawing, and rotate
                // each particle slightly so the field doesn't look like
                // it's marching.
                let rotation = elapsed * particle.spinRate
                localCtx.translateBy(x: position.x, y: position.y)
                localCtx.rotate(by: .radians(rotation))
                localCtx.scaleBy(x: particle.radius / 8.0, y: particle.radius / 8.0)
                localCtx.draw(resolved, at: .zero, anchor: .center)
            }
        }
    }

    /// The symbol list — kept on the type so the field draw loop can
    /// reference an index instead of looking up a name string each frame.
    private func symbolPaletteFor(style: Style) -> [String] {
        switch style {
        case .circles:
            return []
        case .symbols(let names) where names.isEmpty:
            return ["star.fill", "heart.fill", "leaf.fill", "sparkles", "sun.max.fill"]
        case .symbols(let names):
            return names
        }
    }
}

// MARK: - Particle field

/// Plain-old-Swift struct that holds the per-particle state for one burst.
/// We pre-seed 22 particles with randomised velocity vectors and palette
/// indices; the Canvas advances them in pure math instead of mutating
/// State per frame.
private struct ParticleField {
    private(set) var particles: [Particle] = []
    private(set) var startTime: TimeInterval = 0
    private(set) var isActive: Bool = false

    mutating func fire(now: TimeInterval, palette: [Color], symbolCount: Int = 0) {
        startTime = now
        isActive = true
        particles = (0..<22).map { _ in
            // Spread angle ±70° from straight up, biased upward so the
            // burst reads as "rising" before gravity pulls it back.
            let angle = Double.random(in: (.pi * 1.25)...(.pi * 1.75))
            let speed = Double.random(in: 320...560)
            // Symbol particles render larger glyphs — scale the radius
            // band up so canvas.scaleBy(particle.radius / 8) ends up at
            // ~14 pt per glyph instead of ~3 pt.
            let radiusRange: ClosedRange<CGFloat> = symbolCount > 0 ? 9.0...14.0 : 3.0...5.5
            return Particle(
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                spinRate: Double.random(in: -3...3),
                radius: CGFloat.random(in: radiusRange),
                tint: palette.randomElement() ?? NuvyraColors.accent,
                spawnX: Double.random(in: 0.40...0.60),
                spawnY: Double.random(in: 0.55...0.70),
                symbolIndex: symbolCount > 0 ? Int.random(in: 0..<symbolCount) : 0
            )
        }
    }
}

private struct Particle {
    /// Initial velocity vector (points/s).
    let vx: Double
    let vy: Double
    /// Angular velocity (rad/s). Drives the per-symbol rotation so the
    /// glyph field looks like physical tumbling instead of a marching
    /// flat sheet.
    let spinRate: Double
    let radius: CGFloat
    let tint: Color
    /// Spawn position as a 0–1 fraction of the canvas size so the burst
    /// is centred regardless of card width.
    let spawnX: Double
    let spawnY: Double
    /// Which symbol from the palette this particle picked. Always 0 in
    /// `.circles` mode and unused by the disc renderer.
    let symbolIndex: Int

    /// Gravity (points/s²). Matches the feel of Apple's WidgetKit
    /// confetti — fast enough to settle inside the 1.4s window, slow
    /// enough to read as graceful.
    private let gravity: Double = 880

    func position(at elapsed: TimeInterval, in size: CGSize) -> CGPoint {
        let cx = spawnX * Double(size.width)
        let cy = spawnY * Double(size.height)
        let x = cx + vx * elapsed
        let y = cy + vy * elapsed + 0.5 * gravity * elapsed * elapsed
        return CGPoint(x: x, y: y)
    }

    /// Linear fade across the burst. We do the curve in opacity instead
    /// of size so the eye reads "dissolving" instead of "shrinking".
    func opacity(at progress: Double) -> Double {
        let clamped = max(0, min(1, progress))
        return 1 - clamped
    }
}

#if DEBUG
#Preview("Confetti") {
    struct DemoView: View {
        @State private var trigger = false
        var body: some View {
            ZStack {
                NuvyraBackground(.animated)
                NuvyraConfettiBurst(trigger: trigger)
                VStack {
                    Spacer()
                    Button("Fire!") { trigger.toggle() }
                        .font(.headline)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(NuvyraColors.accentGradient, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 60)
                }
            }
        }
    }
    return DemoView()
}
#endif
