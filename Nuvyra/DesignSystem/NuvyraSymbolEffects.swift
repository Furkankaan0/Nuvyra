import SwiftUI

/// Four ambient SF Symbol modifiers we use across the app. iOS 17 ships
/// rich `symbolEffect` primitives; this file picks the ones that pair
/// with Nuvyra's calm tone and wraps them so the call sites stay one
/// line. ReduceMotion is handled inside each modifier — callers don't
/// have to remember to guard.
///
/// Modifiers:
/// - `.nuvyraAmbientIcon()` — soft variable-colour pulse, dim-inactive
///   layers, repeating. Hero card header symbols use this so the page
///   "breathes" even when the data is static.
/// - `.nuvyraGoalBounce(trigger:)` — single bounce when the trigger
///   value changes. Pair with goal-reached flags so the symbol nods
///   on the same beat as the rhythm-hero glow.
/// - `.nuvyraLoadingPulse()` — looping pulse for in-flight async work.
///   Replaces the bare `ProgressView` next to symbols on cards that
///   already carry the symbol as their visual anchor.
/// - `.nuvyraTimedReplace(symbol:value:)` — `contentTransition(.symbolEffect(.replace))`
///   wrapper used wherever a status icon should *cross-fade* between
///   states instead of hard-cutting (e.g. play → stop on the walking
///   focus button).

// MARK: - Ambient icon

struct NuvyraAmbientIconModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating)
        }
    }
}

extension View {
    /// Ambient "this card is alive" pulse — used on hero header symbols.
    /// Hierarchical rendering keeps the pulse contained inside the
    /// glyph's brand-tinted layer instead of fighting the foreground
    /// gradient.
    func nuvyraAmbientIcon() -> some View {
        modifier(NuvyraAmbientIconModifier())
    }
}

// MARK: - Goal bounce

struct NuvyraGoalBounceModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var trigger: Trigger

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce.up, value: trigger)
        }
    }
}

extension View {
    /// Single bounce on every value change. Pair with a goal-reached
    /// flag so the SF Symbol nods at the same time the surrounding card
    /// celebrates.
    func nuvyraGoalBounce<T: Equatable>(trigger: T) -> some View {
        modifier(NuvyraGoalBounceModifier(trigger: trigger))
    }
}

// MARK: - Loading pulse

struct NuvyraLoadingPulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isLoading: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.pulse, options: .repeating, isActive: isLoading)
        }
    }
}

extension View {
    /// Looping pulse on the SF Symbol whenever `isLoading` is true.
    /// Doesn't push a spinner alongside — the symbol is the spinner.
    func nuvyraLoadingPulse(_ isLoading: Bool) -> some View {
        modifier(NuvyraLoadingPulseModifier(isLoading: isLoading))
    }
}

// MARK: - Symbol replace cross-fade

struct NuvyraSymbolReplaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.contentTransition(.symbolEffect(.replace.upUp))
        }
    }
}

extension View {
    /// Apply this on an `Image(systemName:)` that swaps its symbol based
    /// on a state flag. The icon will cross-fade instead of hard-cutting
    /// between the two glyphs.
    func nuvyraSymbolReplace() -> some View {
        modifier(NuvyraSymbolReplaceModifier())
    }
}

#if DEBUG
#Preview("Symbol effects") {
    struct DemoView: View {
        @State private var goalReached = false
        @State private var isLoading = false
        @State private var play = true

        var body: some View {
            ZStack {
                NuvyraBackground(.animated)
                VStack(spacing: NuvyraSpacing.lg) {
                    HStack(spacing: NuvyraSpacing.lg) {
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NuvyraColors.accent)
                            .nuvyraAmbientIcon()
                        Text("Ambient").font(.headline)
                    }

                    HStack(spacing: NuvyraSpacing.lg) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NuvyraColors.accent)
                            .nuvyraGoalBounce(trigger: goalReached)
                        Toggle("Goal", isOn: $goalReached)
                    }

                    HStack(spacing: NuvyraSpacing.lg) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.largeTitle)
                            .foregroundStyle(NuvyraColors.accent)
                            .nuvyraLoadingPulse(isLoading)
                        Toggle("Loading", isOn: $isLoading)
                    }

                    HStack(spacing: NuvyraSpacing.lg) {
                        Image(systemName: play ? "play.fill" : "stop.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NuvyraColors.accent)
                            .nuvyraSymbolReplace()
                        Toggle("Play", isOn: $play)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg))
                .padding()
            }
        }
    }
    return DemoView()
}
#endif
