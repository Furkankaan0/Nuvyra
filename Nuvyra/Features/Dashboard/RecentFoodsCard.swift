import SwiftUI

struct RecentFoodsCard: View {
    var entries: [RecentFoodLog]
    var onSeeAll: () -> Void

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Son eklenen besinler")
                            .font(NuvyraTypography.section)
                        Text("Bugünkü kayıtların")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onSeeAll) {
                        Text("Tümü")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .buttonStyle(.plain)
                }
                if entries.isEmpty {
                    InlineEmptyState(
                        icon: "fork.knife",
                        title: "Henüz besin eklemedin",
                        subtitle: "Hızlı işlemler bölümünden ekleyebilirsin."
                    )
                } else {
                    VStack(spacing: NuvyraSpacing.sm) {
                        ForEach(entries) { entry in
                            RecentFoodRow(entry: entry)
                        }
                    }
                }
            }
        }
    }
}

private struct RecentFoodRow: View {
    var entry: RecentFoodLog

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            MealPhotoThumbnail(
                data: entry.photoData,
                fallbackSystemImage: entry.mealType.systemImage,
                size: 40,
                cornerRadius: 14
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(entry.mealType.title) • \(entry.portion)")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.calories) kcal")
                    .font(.subheadline.weight(.bold))
                Text(entry.relativeTimeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct InlineEmptyState: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 44, height: 44)
                .background(NuvyraColors.accent.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(NuvyraTypography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

#if DEBUG
#Preview("Recent foods") {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            RecentFoodsCard(entries: DashboardPreviewData.recentFoods, onSeeAll: {})
            RecentFoodsCard(entries: [], onSeeAll: {})
        }
        .padding()
    }
}
#endif
