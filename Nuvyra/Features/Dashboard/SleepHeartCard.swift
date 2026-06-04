import SwiftUI

/// Dashboard card pairing last night's sleep with the freshest resting
/// heart rate. Lives behind a `NuvyraVitalsService` so first-launch
/// users without HealthKit data still see calm fallback copy instead
/// of zeroes.
///
/// Two glass medallions stacked horizontally, each with an SF Symbol
/// and the numeric value formatted in Turkish locale. Hides itself
/// entirely when *both* values are nil — better to show no card than
/// a deceptive empty one.
struct SleepHeartCard: View {
    @Environment(\.colorScheme) private var scheme
    var vitals: NuvyraVitalsSnapshot

    private var hasAny: Bool {
        vitals.lastNightHours != nil || vitals.restingHeartRate != nil
    }

    var body: some View {
        if hasAny {
            NuvyraGlassCard(.prominent) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    header
                    HStack(spacing: NuvyraSpacing.md) {
                        metric(
                            tint: NuvyraColors.softMint,
                            symbol: "moon.zzz.fill",
                            label: "Uyku",
                            value: vitals.lastNightHours.map { String(format: "%.1f sa", $0).replacingOccurrences(of: ".", with: ",") } ?? "—"
                        )
                        metric(
                            tint: NuvyraColors.mutedCoral,
                            symbol: "heart.fill",
                            label: "İstirahat nabzı",
                            value: vitals.restingHeartRate.map { "\($0) bpm" } ?? "—"
                        )
                    }
                    if vitals.lastNightHours == nil || vitals.restingHeartRate == nil {
                        missingHint
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Toparlanma")
                    .font(NuvyraTypography.section)
                Text("Uyku ve nabız")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .nuvyraAmbientIcon()
        }
    }

    private func metric(tint: Color, symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            HStack(spacing: NuvyraSpacing.xs) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(tint.opacity(scheme == .dark ? 0.22 : 0.16))
                    Circle().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6)
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)

                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(NuvyraSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(scheme == .dark ? 0.10 : 0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }

    private var missingHint: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.softSand)
            Text("Apple Saat veya uyku takip uygulaması verisi yoksa eksik kalan değerler '—' olarak görünür.")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityLabel: String {
        let sleep = vitals.lastNightHours.map { "\(String(format: "%.1f", $0)) saat uyku" } ?? "uyku verisi yok"
        let rhr = vitals.restingHeartRate.map { "istirahat nabzı \($0) bpm" } ?? "nabız verisi yok"
        return "Toparlanma: \(sleep), \(rhr)."
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground(.animated)
        VStack(spacing: NuvyraSpacing.md) {
            SleepHeartCard(vitals: NuvyraVitalsSnapshot(lastNightHours: 7.4, restingHeartRate: 62))
            SleepHeartCard(vitals: NuvyraVitalsSnapshot(lastNightHours: nil, restingHeartRate: 58))
            SleepHeartCard(vitals: NuvyraVitalsSnapshot(lastNightHours: 6.2, restingHeartRate: nil))
        }
        .padding()
    }
}
#endif
