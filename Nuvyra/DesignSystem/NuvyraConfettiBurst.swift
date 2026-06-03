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
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            field.fire(now: Date().timeIntervalSinceReferenceDate, palette: palette)
        }
    }

    // MARK: - Drawing

    private func drawField(ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let progress = elapsed / duration
        for particle in field.particles {
            let position = particle.position(at: elapsed, in: size)
            let alpha = particle.opacity(at: progress)
            guard alpha > 0.01 else { continue }
            let rect = CGRect(
                x: position.x - particle.radius,
                y: position.y - particle.radius,
                width: particle.radius * 2,
                height: particle.radius * 2
            )
            var localCtx = ctx
            localCtx.opacity = alpha
            localCtx.fill(Path(ellipseIn: rect), with: .color(particle.tint))
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

    mutating func fire(now: TimeInterval, palette: [Color]) {
        startTime = now
        isActive = true
        particles = (0..<22).map { _ in
            // Spread angle ±70° from straight up, biased upward so the
            // burst reads as "rising" before gravity pulls it back.
            let angle = Double.random(in: (.pi * 1.25)...(.pi * 1.75))
            let speed = Double.random(in: 320...560)
            return Particle(
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                spinRate: Double.random(in: -3...3),
                radius: CGFloat.random(in: 3.0...5.5),
                tint: palette.randomElement() ?? NuvyraColors.accent,
                spawnX: Double.random(in: 0.40...0.60),
                spawnY: Double.random(in: 0.55...0.70)
            )
        }
    }
}

private struct Particle {
    /// Initial velocity vector (points/s).
    let vx: Double
    let vy: Double
    /// Reserved for future shape rotation — currently the renderer draws
    /// circles which don't need orientation.
    let spinRate: Double
    let radius: CGFloat
    let tint: Color
    /// Spawn position as a 0–1 fraction of the canvas size so the burst
    /// is centred regardless of card width.
    let spawnX: Double
    let spawnY: Double

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
