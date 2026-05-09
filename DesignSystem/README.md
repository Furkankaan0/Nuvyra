# Nuvyra Design System

Apple Design Award seviyesinde, premium wellness tasarım dilini SwiftUI'da
kodlayan modüler bir sistem. Light/Dark mode kusursuz, Dynamic Type ve
VoiceOver uyumlu, frosted glass + soft gradient + 3D katmanlı gölge ile
derinlik hissi sağlar.

## Hedeflenen Platform

- **iOS 17+** (Charts modülünde `SectorMark`, `chartScrollableAxes`,
  `proxy.plotFrame` ile zorunlu).
- Tüm bileşenler 6.7" ve 4.7" ekranlarda test edilmek üzere tasarlanmıştır.

## Klasör Yapısı

```
DesignSystem/
├── Tokens/
│   ├── DesignTokens.swift         // Umbrella + NuvyraPageBackground
│   ├── AppColors.swift            // Light/Dark dynamic palette + gradients
│   ├── AppTypography.swift        // SF Rounded + Dynamic Type uyumlu
│   ├── AppSpacing.swift           // 4pt grid (xxxs … xxxl)
│   ├── AppRadius.swift            // continuous squircle factory
│   └── AppShadow.swift            // 2-katmanlı gölge stack'leri
├── Components/
│   ├── Cards/
│   │   ├── PremiumCard.swift
│   │   ├── GlassCard.swift
│   │   ├── MacroProgressCard.swift
│   │   └── DailySummaryCard.swift
│   ├── Buttons/
│   │   ├── PrimaryButton.swift
│   │   ├── SecondaryButton.swift  // outline / soft / ghost
│   │   └── FloatingActionButton.swift
│   ├── Feedback/
│   │   ├── LoadingSkeleton.swift  // shimmer + atom factory
│   │   ├── EmptyStateView.swift
│   │   ├── ErrorStateView.swift
│   │   └── SuccessToast.swift
│   └── Visual/
│       ├── PremiumBadge.swift     // gold / mint / neutral
│       └── CalorieRingView.swift  // Apple Fitness benzeri 3 ring
├── Charts/
│   ├── ChartDownsampler.swift     // ay/yıl seviyesinde alt-örnekleme
│   ├── MacroDonutChart.swift      // SectorMark + tap selection
│   ├── CalorieTrendChart.swift    // LineMark + AreaMark + drag select
│   └── WeeklyStepsChart.swift     // BarMark + scrollable + checkmark
└── Showcase/
    └── DesignSystemShowcase.swift // tüm bileşenler tek ekran
```

## Token kullanımı

```swift
Text("Bugün")
    .font(AppTypography.titleSmall)
    .foregroundStyle(AppColors.textPrimary)
    .padding(AppSpacing.md)
    .background(
        AppRadius.shape(AppRadius.lg)
            .fill(AppColors.surface)
    )
    .nuvyraCardShadow()
```

## Erişilebilirlik

- Tüm renkler **Light/Dark** için ayrı hex; `UIColor` dynamic provider ile çözülür.
- Tipografi `Font.system(...).leading(.tight)` sistem stiline bağlı; **Dynamic Type**
  kullanıcı font boyutu değişiminde tüm metin yeniden ölçeklenir.
- Tüm interaktif bileşenler `.accessibilityLabel`, `.accessibilityValue` ve
  `.accessibilityAddTraits(.isButton)` ile etiketlenmiştir.
- Chartlarda **VoiceOver** her veri noktasını okur:
  - "Pazartesi 8.500 adım, hedefe ulaşıldı"
  - "Protein 78 gram, yüzde 30"
- Skeleton ve dekoratif görseller `.accessibilityHidden(true)`.

## Üç Grafik

1. **MacroDonutChart** — `SectorMark`, `innerRadius: .ratio(0.618)` (altın oran),
   `angularInset: 2`, 0.8 sn easeOut açılış animasyonu, dokununca seçilen
   dilim öne çıkar (diğerleri opacity 0.4'e düşer).
2. **CalorieTrendChart** — `LineMark` + `AreaMark` (yeşil → şeffaf),
   `interpolationMethod: .catmullRom`, kesik çizgi ile hedef, sürükleyince
   `PointMark` + frosted callout.
3. **WeeklyStepsChart** — `BarMark` (cornerRadius 6), hedefe ulaşılan günler
   yeşil + checkmark annotation, kalanlar turuncu, `chartScrollableAxes(.horizontal)`
   ile haftalar arası kaydırma.

Hepsi `ChartDownsampler.downsample(_:targetCount:)` ile ay/yıl seviyesi
veride otomatik 200 noktaya düşürülür.

## Kullanım örneği

```swift
import SwiftUI

@MainActor
struct DashboardView: View {
    @State private var toast: ToastConfig?

    var body: some View {
        ZStack {
            NuvyraPageBackground()
            ScrollView {
                VStack(spacing: AppSpacing.sectionGap) {
                    DailySummaryCard(
                        consumed: 1842, target: 2400, burned: 412,
                        waterMl: 1500, waterTargetMl: 2500,
                        stepCount: 6480, stepTarget: 10000
                    )
                    HStack(spacing: 12) {
                        MacroProgressCard(title: "Protein", consumed: 78, target: 120,
                                          tint: AppColors.macroProtein, icon: "fish.fill")
                        MacroProgressCard(title: "Karb", consumed: 145, target: 220,
                                          tint: AppColors.macroCarbs, icon: "leaf.fill")
                        MacroProgressCard(title: "Yağ", consumed: 42, target: 70,
                                          tint: AppColors.macroFat, icon: "drop.fill")
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
            }
            VStack {
                Spacer()
                FloatingActionButton(icon: "plus", label: "Öğün ekle") {
                    toast = .init(title: "Öğün eklendi", kind: .success)
                }
                .padding(.bottom, 24)
            }
        }
        .successToast($toast)
    }
}
```

## Showcase

Tüm bileşenleri tek scrollable ekranda görmek için:

```swift
NavigationStack { DesignSystemShowcase() }
```

Light + Dark preview'leri her bileşen dosyasında ayrıca mevcuttur.
