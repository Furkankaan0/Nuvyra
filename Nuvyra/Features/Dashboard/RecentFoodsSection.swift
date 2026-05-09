import SwiftUI

struct RecentFoodsSection: View {
    @Environment(\.colorScheme) private var scheme
    var items: [RecentFoodLog]
    var onSeeAll: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                NuvyraSectionHeader(title: "Son eklenen besinler", subtitle: "Son birkaç kayıt.")
                Spacer()
                Button(action: onSeeAll) {
                    Text("Tümü")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tümünü göster")
            }

            if items.isEmpty {
                EmptyRecentFoods()
            } else {
                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(items.prefix(5)) { item in
                        HStack(spacing: NuvyraSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(NuvyraColors.accent.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: item.mealType.systemImage)
                                    .foregroundStyle(NuvyraColors.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(item.mealType.title) • \(item.portion)")
                                    .font(.caption)
                                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.calories) kcal")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                                Text(Self.timeFormatter.string(from: item.loggedAt))
                                    .font(.caption2)
                                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(NuvyraSpacing.md)
                .background(NuvyraColors.card(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                        .stroke(NuvyraColors.accent.opacity(0.10))
                )
            }
        }
    }
}

private struct EmptyRecentFoods: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(NuvyraColors.accent)
            Text("Henüz besin kaydı yok")
                .font(.subheadline.weight(.semibold))
            Text("Yemek ekle, barkod tara veya sesle ekle ile günü başlat.")
                .font(.caption)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(NuvyraSpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Filled") {
    RecentFoodsSection(items: DashboardMockPreviewData.recentFoods, onSeeAll: {})
        .padding()
        .background(NuvyraBackground())
}

#Preview("Empty") {
    RecentFoodsSection(items: [], onSeeAll: {})
        .padding()
        .background(NuvyraBackground())
}
#endif
