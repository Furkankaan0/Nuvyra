import SwiftUI
import WidgetKit

// MARK: - Background

struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = NuvyraColors.accent
    var secondary: Color = NuvyraColors.softMint

    var body: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme)
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.18 : 0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -90, y: -100)
            Circle()
                .fill(secondary.opacity(scheme == .dark ? 0.16 : 0.20))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 110, y: 120)
        }
    }
}

// MARK: - Progress ring with safe inner content

struct WidgetRing: View {
    var progress: Double
    var lineWidth: CGFloat = 9
    var trackColor: Color = NuvyraColors.accent.opacity(0.18)
    var gradientColors: [Color] = [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent]

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let ringSize = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(colors: gradientColors, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Ring that hosts safe-bounded inner text (auto-scaled, never clipped).
struct WidgetRingWithLabel: View {
    var progress: Double
    var primary: String
    var caption: String
    var lineWidth: CGFloat = 9
    var gradientColors: [Color] = [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent]

    var body: some View {
        ZStack {
            WidgetRing(progress: progress, lineWidth: lineWidth, gradientColors: gradientColors)
            VStack(spacing: 1) {
                Text(primary)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                Text(caption)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, lineWidth * 2.4)
            .padding(.vertical, lineWidth * 0.6)
        }
    }
}

// MARK: - Horizontal gradient bar

struct WidgetGradientBar: View {
    var progress: Double
    var tint: Color
    var background: Color?
    var height: CGFloat = 6

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(background ?? tint.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * CGFloat(clamped), clamped > 0 ? 4 : 0))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Glass-style metric tile

struct WidgetMetricTile: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var value: String
    var unit: String?
    var systemImage: String
    var tint: Color
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.system(size: 11, weight: .heavy))
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if let progress {
                WidgetGradientBar(progress: progress, tint: tint, height: 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.18)))
    }
}

// MARK: - Auto-fitting label

struct WidgetEyebrow: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(NuvyraColors.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Number formatting helpers

enum WidgetFormat {
    static func compact(_ number: Int) -> String {
        if number >= 10_000 {
            let thousands = Double(number) / 1_000.0
            return String(format: "%.1fk", thousands)
        }
        return number.formatted(.number.grouping(.automatic))
    }

    static func water(_ ml: Int) -> String {
        if ml >= 1_000 {
            let liters = Double(ml) / 1_000.0
            return String(format: "%.1fL", liters)
        }
        return "\(ml)ml"
    }
}
