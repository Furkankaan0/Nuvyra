import SwiftUI

/// History row for a workout. Manual entries are editable/deletable; HealthKit
/// entries are surfaced read-only with a small Apple Health badge.
struct WorkoutRow: View {
    var entry: WorkoutEntry
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        let isEditable = entry.source == .manual && onEdit != nil
        return Group {
            if isEditable, let onEdit {
                Button(action: onEdit) { content }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                        Button(action: onEdit) {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        .tint(NuvyraColors.accent)
                    }
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.type.title), \(entry.durationMinutes) dakika, \(entry.caloriesBurned) kalori")
    }

    private var content: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Image(systemName: entry.type.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(entry.type.tint)
                .frame(width: 38, height: 38)
                .background(entry.type.tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.type.title)
                        .font(.subheadline.weight(.semibold))
                    if entry.source == .healthKit {
                        Image(systemName: "applelogo")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NuvyraColors.mutedCoral)
                    }
                }
                HStack(spacing: 4) {
                    Text("\(entry.durationMinutes) dk")
                    if let km = entry.distanceKm, km > 0 {
                        Text("·")
                        Text(String(format: "%.1f km", km))
                    }
                    Text("·")
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(entry.caloriesBurned) kcal")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(entry.type.tint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
