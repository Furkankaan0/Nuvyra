import SwiftUI

/// History row — appears in the BodyMeasurementsView list. Swipe to delete,
/// tap to edit.
struct BodyMeasurementRow: View {
    var log: WeightLog
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: "ruler")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 38, height: 38)
                    .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    measurementChips
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f kg", log.weightKg))
                        .font(.subheadline.weight(.bold))
                    if let bf = log.bodyFatPercent {
                        Text(String(format: "Yağ %%%.1f", bf))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(NuvyraColors.mutedCoral)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(NuvyraColors.accent)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var measurementChips: some View {
        HStack(spacing: 4) {
            if let waist = log.waistCm { chip("Bel", value: waist) }
            if let hip = log.hipCm { chip("Kalça", value: hip) }
            if let chest = log.chestCm { chip("Göğüs", value: chest) }
            if let ratio = log.waistToHipRatio {
                Text(String(format: "BKO %.2f", ratio))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NuvyraColors.softMint.opacity(0.18), in: Capsule())
                    .foregroundStyle(NuvyraColors.accent)
            }
            if !log.hasBodyComposition {
                Text("Sadece kilo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ label: String, value: Double) -> some View {
        Text("\(label) \(value.cleanFormatted)cm")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(NuvyraColors.accent.opacity(0.10), in: Capsule())
            .foregroundStyle(NuvyraColors.accent)
    }
}
