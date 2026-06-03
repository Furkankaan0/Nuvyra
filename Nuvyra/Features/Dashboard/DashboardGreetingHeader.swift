import SwiftUI

/// Top-of-Dashboard greeting. Gradient-filled name + time-aware micro-icon +
/// formatted date sits beneath. The icon picks up the same accent gradient
/// the brand wordmark uses so the eye reads "Nuvyra welcome" before
/// scanning the metric cards below.
struct DashboardGreetingHeader: View {
    @Environment(\.colorScheme) private var scheme
    var name: String
    var date: Date

    private enum TimeBand {
        case morning, midday, evening, night

        var greetingKey: String {
            switch self {
            case .morning: "Günaydın"
            case .midday: "Merhaba"
            case .evening: "İyi akşamlar"
            case .night: "İyi geceler"
            }
        }

        var symbol: String {
            switch self {
            case .morning: "sun.max.fill"
            case .midday: "sun.haze.fill"
            case .evening: "sunset.fill"
            case .night: "moon.stars.fill"
            }
        }

        var tint: Color {
            switch self {
            case .morning: NuvyraColors.softMint
            case .midday: NuvyraColors.accent
            case .evening: NuvyraColors.softSand
            case .night: NuvyraColors.mutedCoral
            }
        }

        static func band(for date: Date) -> TimeBand {
            let hour = Calendar.nuvyra.component(.hour, from: date)
            switch hour {
            case 5..<11: return .morning
            case 11..<17: return .midday
            case 17..<22: return .evening
            default: return .night
            }
        }
    }

    private var band: TimeBand { TimeBand.band(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            HStack(alignment: .center, spacing: NuvyraSpacing.sm) {
                // Time-of-day glass medallion — small, glanceable, sits to
                // the left of the greeting so the icon and headline read as
                // one visual unit.
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(band.tint.opacity(scheme == .dark ? 0.20 : 0.16))
                    Circle()
                        .stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.7)
                    Image(systemName: band.symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(band.tint)
                }
                .frame(width: 40, height: 40)
                .nuvyraShadow(.ambient, scheme: scheme)

                Text("\(band.greetingKey), \(name)")
                    .font(NuvyraTypography.hero)
                    .foregroundStyle(headlineGradient)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Text(DateFormatter.nuvyraShortDate.string(from: date).capitalized)
                .font(NuvyraTypography.body)
                .foregroundStyle(.secondary)
                .padding(.leading, 52)  // align under the headline, after the medallion
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(band.greetingKey), \(name). \(DateFormatter.nuvyraShortDate.string(from: date))")
    }

    /// Headline gradient — picks up the brand accent at one end and the
    /// time-band tint at the other so the greeting shifts colour subtly
    /// across the day.
    private var headlineGradient: LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [NuvyraColors.darkText, band.tint.opacity(0.88)]
                : [NuvyraColors.lightText, band.tint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.lg) {
            DashboardGreetingHeader(name: "Furkan", date: Date())
            DashboardGreetingHeader(name: "Furkan", date: Date())
        }
        .padding()
    }
}
#endif
