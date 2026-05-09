import SwiftUI

// MARK: - Mesh-style animated background

struct OnboardingMeshBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    var accentTint: Color = NuvyraColors.accent

    var body: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme)
                .ignoresSafeArea()

            blob(color: accentTint.opacity(scheme == .dark ? 0.28 : 0.32),
                 size: 360,
                 offset: CGPoint(x: -160 + phase * 18, y: -240 - phase * 12),
                 blur: 80)

            blob(color: NuvyraColors.softMint.opacity(scheme == .dark ? 0.22 : 0.34),
                 size: 320,
                 offset: CGPoint(x: 160 - phase * 14, y: 280 + phase * 10),
                 blur: 70)

            blob(color: NuvyraColors.softSand.opacity(scheme == .dark ? 0.18 : 0.32),
                 size: 280,
                 offset: CGPoint(x: 130 + phase * 16, y: -120 + phase * 8),
                 blur: 60)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func blob(color: Color, size: CGFloat, offset: CGPoint, blur: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: offset.x, y: offset.y)
    }
}

// MARK: - Floating dot progress

struct OnboardingProgressDots: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var currentIndex: Int
    var total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex
                          ? AnyShapeStyle(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(NuvyraColors.accent.opacity(index < currentIndex ? 0.45 : 0.18)))
                    .frame(width: index == currentIndex ? 22 : 6, height: 6)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78), value: currentIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adım \(currentIndex + 1) / \(total)")
    }
}

// MARK: - Hero icon with glow halo and 3D tilt

struct OnboardingHeroHalo: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var systemImage: String
    var tint: Color = NuvyraColors.accent
    var secondary: Color = NuvyraColors.softMint
    @State private var pulse = false
    @State private var tilt: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.55), secondary.opacity(0.32), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: pulse ? 16 : 10)
                .scaleEffect(pulse ? 1.08 : 0.94)
                .opacity(0.9)

            Circle()
                .strokeBorder(
                    Color.white.opacity(scheme == .dark ? 0.12 : 0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                )
                .frame(width: 188, height: 188)
                .rotationEffect(.degrees(reduceMotion ? 0 : pulse ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 28).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint, secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.45), radius: 28, x: 0, y: 18)

            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .shadow(color: tint.opacity(0.5), radius: 8)
        }
        .rotation3DEffect(.degrees(tilt), axis: (x: 0.4, y: 1, z: 0), perspective: 0.5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                tilt = 6
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Eyebrow + headline layout

struct OnboardingEyebrow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var eyebrow: String?
    var title: String
    var subtitle: String?
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(NuvyraColors.accent)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 12)
            }
            Text(title)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .lineSpacing(2)
                .foregroundStyle(NuvyraColors.primaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)
            if let subtitle {
                Text(subtitle)
                    .font(.body.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(.easeOut(duration: 0.5).delay(0.05)) { visible = true }
            }
        }
    }
}

// MARK: - Selectable tile (gender / activity / goal / pace)

struct OnboardingSelectableTile: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var subtitle: String
    var symbol: String
    var trailingText: String?
    var isSelected: Bool
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? AnyShapeStyle(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(NuvyraColors.accent.opacity(0.12)))
                        .frame(width: 46, height: 46)
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .foregroundStyle(NuvyraColors.accent)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.clear : NuvyraColors.accent.opacity(0.32), lineWidth: 1.4)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)
                    if isSelected {
                        RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                            .fill(LinearGradient(
                                colors: [NuvyraColors.accent.opacity(0.18), NuvyraColors.softMint.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.5) : Color.white.opacity(scheme == .dark ? 0.08 : 0.32), lineWidth: 1)
            )
            .shadow(color: isSelected ? NuvyraColors.accent.opacity(0.22) : NuvyraShadow.card(scheme), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Ruler-style horizontal number picker

struct OnboardingRulerPicker: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var value: Int
    var range: ClosedRange<Int>
    var unit: String
    var symbol: String
    var tint: Color = NuvyraColors.accent
    @State private var lastHaptic: Int = .min

    private let tickSpacing: CGFloat = 12

    var body: some View {
        VStack(spacing: NuvyraSpacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [tint, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: tint.opacity(0.32), radius: 14, x: 0, y: 8)
                    Image(systemName: symbol)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("\(value)")
                    .font(.system(size: 86, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .frame(maxHeight: 92)
                    .accessibilityLabel("\(value) \(unit)")
                Text(unit)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            .padding(.horizontal, 4)

            ruler
        }
    }

    private var ruler: some View {
        GeometryReader { proxy in
            let center = proxy.size.width / 2
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: tickSpacing) {
                        ForEach(range, id: \.self) { number in
                            Tick(number: number,
                                 isMajor: number % 5 == 0,
                                 isCurrent: number == value,
                                 unitSuffix: unit,
                                 tint: tint)
                                .id(number)
                        }
                    }
                    .padding(.horizontal, center - 14)
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: contentProxy.frame(in: .named("ruler")).minX
                            )
                        }
                    )
                }
                .coordinateSpace(name: "ruler")
                .onAppear {
                    DispatchQueue.main.async {
                        scrollProxy.scrollTo(value, anchor: .center)
                    }
                }
                .onChange(of: value) { _, newValue in
                    withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    let totalUnits = Double(range.upperBound - range.lowerBound)
                    let totalWidth = Double(totalUnits) * Double(tickSpacing)
                    let normalized = max(min(-Double(offset) / totalWidth, 1), 0)
                    let proposed = Int((Double(range.lowerBound) + normalized * totalUnits).rounded())
                    let clamped = max(min(proposed, range.upperBound), range.lowerBound)
                    if clamped != value {
                        value = clamped
                        if !reduceMotion, lastHaptic != clamped {
                            lastHaptic = clamped
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
                        }
                    }
                }
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(LinearGradient(colors: [tint, NuvyraColors.softMint], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 64)
                        .shadow(color: tint.opacity(0.5), radius: 6, x: 0, y: 2)
                        .allowsHitTesting(false)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .frame(height: 96)
        .accessibilityElement()
        .accessibilityLabel("\(unit) seçici")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

private struct Tick: View {
    @Environment(\.colorScheme) private var scheme
    let number: Int
    let isMajor: Bool
    let isCurrent: Bool
    let unitSuffix: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(isCurrent ? tint : NuvyraColors.secondaryText(scheme).opacity(isMajor ? 0.55 : 0.25))
                .frame(width: isMajor ? 3 : 2, height: isMajor ? 38 : 22)
            if isMajor {
                Text("\(number)")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(isCurrent ? tint : NuvyraColors.secondaryText(scheme))
            } else {
                Color.clear.frame(height: 12)
            }
        }
        .frame(width: 16)
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Continue button (floating, gradient)

struct OnboardingContinueButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var systemImage: String
    var isEnabled: Bool
    var isLoading: Bool
    var action: () -> Void
    @State private var glow: CGFloat = 0
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
                if !isLoading {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(
                ZStack {
                    Capsule()
                        .fill(LinearGradient(
                            colors: isEnabled
                                ? [NuvyraColors.accent, NuvyraColors.softMint]
                                : [NuvyraColors.accent.opacity(0.4), NuvyraColors.softMint.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    if isEnabled {
                        Capsule()
                            .stroke(Color.white.opacity(0.25 + 0.18 * glow), lineWidth: 1)
                    }
                }
            )
            .shadow(color: NuvyraColors.accent.opacity(isEnabled ? 0.32 + 0.18 * glow : 0), radius: 18, x: 0, y: 12)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed, isEnabled, !isLoading else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .onAppear {
            guard !reduceMotion, isEnabled else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = 1 }
        }
        .onChange(of: isEnabled) { _, enabled in
            guard !reduceMotion else { return }
            if enabled {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = 1 }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) { glow = 0 }
            }
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Metric badge (used in summary)

struct OnboardingMetricBadge: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var value: String
    var unit: String?
    var symbol: String
    var tint: Color
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: tint.opacity(0.32), radius: 6, x: 0, y: 3)

            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(tint.opacity(0.22))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 10, x: 0, y: 6)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 18)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double.random(in: 0.05...0.25))) {
                visible = true
            }
        }
    }
}
