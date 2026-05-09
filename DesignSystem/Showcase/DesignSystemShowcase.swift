//
//  DesignSystemShowcase.swift
//  Nuvyra Design System
//
//  Tüm bileşenleri tek scrollable ekranda gösteren live demo.
//  Geliştirici sayfası — App Store build'ine eklenmez.
//

import SwiftUI

public struct DesignSystemShowcase: View {

    // MARK: - State

    @State private var toast: ToastConfig?
    @State private var isLoading = false

    // MARK: - Body

    public init() {}

    public var body: some View {
        ZStack {
            NuvyraPageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    header
                    summarySection
                    macrosSection
                    chartsSection
                    buttonsSection
                    feedbackSection
                    badgeSection
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
        .successToast($toast)
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nuvyra")
                .font(AppTypography.displayLarge)
                .foregroundStyle(AppColors.textPrimary)
            Text("Premium wellness design system")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Daily Summary")
            DailySummaryCard(
                consumed: 1842, target: 2400, burned: 412,
                waterMl: 1500, waterTargetMl: 2500,
                stepCount: 6480, stepTarget: 10000
            )
        }
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Macros")
            HStack(spacing: 12) {
                MacroProgressCard(title: "Protein", consumed: 78, target: 120,
                                  tint: AppColors.macroProtein, icon: "fish.fill")
                MacroProgressCard(title: "Karb",     consumed: 145, target: 220,
                                  tint: AppColors.macroCarbs, icon: "leaf.fill")
                MacroProgressCard(title: "Yağ",      consumed: 42,  target: 70,
                                  tint: AppColors.macroFat, icon: "drop.fill")
            }
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Charts")

            PremiumCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Makro Dağılımı")
                        .font(AppTypography.titleSmall)
                    MacroDonutChart(
                        slices: [
                            .init(label: "Protein", grams: 78,  color: AppColors.macroProtein),
                            .init(label: "Karb",    grams: 145, color: AppColors.macroCarbs),
                            .init(label: "Yağ",     grams: 42,  color: AppColors.macroFat)
                        ],
                        centerTitle: "265 g",
                        centerSubtitle: "toplam makro"
                    )
                    .frame(height: 240)
                }
            }

            PremiumCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Son 30 Gün Kalori")
                        .font(AppTypography.titleSmall)
                    CalorieTrendChart(
                        data: ShowcaseData.calories(),
                        dailyTarget: 2300
                    )
                    .frame(height: 220)
                }
            }

            PremiumCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Haftalık Adımlar")
                        .font(AppTypography.titleSmall)
                    WeeklyStepsChart(data: ShowcaseData.steps())
                        .frame(height: 200)
                }
            }
        }
    }

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Buttons")
            VStack(spacing: 10) {
                PrimaryButton("Premium'a Geç", icon: "sparkles") {
                    toast = .init(title: "Yönlendiriliyor", kind: .info)
                }
                SecondaryButton("Outline", icon: "square.and.pencil") {}
                SecondaryButton("Soft", icon: "heart", style: .soft) {}
                HStack {
                    Spacer()
                    FloatingActionButton(icon: "plus", label: "Öğün ekle") {
                        toast = .init(title: "Öğün eklendi",
                                      subtitle: "247 kcal", kind: .success)
                    }
                    Spacer()
                }
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Feedback")

            PremiumCard {
                VStack(spacing: 12) {
                    LoadingSkeleton.card(height: 80)
                    ListItemSkeleton()
                    ListItemSkeleton()
                }
            }

            PremiumCard {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "Henüz öğün yok",
                    subtitle: "İlk öğününü ekle.",
                    actionTitle: "Öğün Ekle",
                    action: {}
                )
            }

            PremiumCard {
                ErrorStateView(
                    message: "Bağlantı hatası. Tekrar dener misin?",
                    onRetry: {
                        toast = .init(title: "Yeniden deneniyor", kind: .info)
                    }
                )
            }
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Badges")
            HStack(spacing: 10) {
                PremiumBadge(label: "Premium", icon: "crown.fill", style: .gold)
                PremiumBadge(label: "Streak 7", icon: "flame.fill", style: .mint)
                PremiumBadge(label: "Yeni", icon: nil, style: .neutral)
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)
    }
}

// MARK: - Demo Data

private enum ShowcaseData {
    static func calories() -> [CalorieDataPoint] {
        let cal = Calendar.current
        return (0..<30).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: .now)!
            let base = 2200.0
            let noise = Double.random(in: -350...250)
            return CalorieDataPoint(date: date, kcal: max(1200, base + noise))
        }
    }

    static func steps() -> [DailyStepsPoint] {
        let cal = Calendar.current
        let counts = [8200, 11200, 5800, 9700, 12300, 4500, 10800,
                      9100, 11600, 7400, 13200, 8900, 6200, 12700]
        return counts.enumerated().reversed().map { idx, steps in
            let date = cal.date(byAdding: .day, value: -idx, to: .now)!
            return DailyStepsPoint(date: date, steps: steps)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    NavigationStack { DesignSystemShowcase() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack { DesignSystemShowcase() }
        .preferredColorScheme(.dark)
}
#endif
