import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: 0) {
                OnboardingProgressHeader(progress: viewModel.progress, stepLabel: viewModel.stepLabel)
                    .padding(.horizontal, NuvyraSpacing.lg)
                    .padding(.top, NuvyraSpacing.md)

                ScrollView(showsIndicators: false) {
                    OnboardingStepContent(viewModel: viewModel)
                        .id(viewModel.currentStep.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.top, NuvyraSpacing.lg)
                        .padding(.bottom, 156)
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: viewModel.pageIndex)
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingControlBar(
                canGoBack: viewModel.pageIndex > 0,
                primaryTitle: viewModel.primaryButtonTitle,
                primaryIcon: viewModel.primaryButtonIcon,
                isCompleting: viewModel.isCompleting,
                errorMessage: viewModel.errorMessage,
                onBack: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                        viewModel.back()
                    }
                },
                onPrimary: {
                    if viewModel.isLastPage {
                        Task { await viewModel.complete(context: modelContext, dependencies: dependencies) }
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                            viewModel.next()
                        }
                    }
                }
            )
        }
        .task { await dependencies.analytics.track(.onboardingStarted, payload: AnalyticsPayload()) }
        .alert("Başlangıç tamamlanamadı", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Lütfen tekrar dene.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }
}

private struct OnboardingStepContent: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView()
            case .gender:
                GenderSelectionStep(selectedGender: $viewModel.selectedGender)
            case .age:
                NumberPickerStep(
                    eyebrow: "Profil",
                    title: "Yaşını seç.",
                    subtitle: "Nuvyra günlük enerji hedefini yaşına göre daha gerçekçi ayarlar.",
                    value: $viewModel.age,
                    range: 13...100,
                    unit: "yaş",
                    symbol: "calendar"
                )
            case .height:
                NumberPickerStep(
                    eyebrow: "Vücut ölçüsü",
                    title: "Boyunu seç.",
                    subtitle: "BMR ve günlük su hedefini hesaplarken santimetre bazlı ölçüm kullanırız.",
                    value: $viewModel.heightCm,
                    range: 130...220,
                    unit: "cm",
                    symbol: "ruler"
                )
            case .weight:
                NumberPickerStep(
                    eyebrow: "Vücut ölçüsü",
                    title: "Kilonu seç.",
                    subtitle: "Kalori, makro ve su hedeflerinin temelini bu değer oluşturur.",
                    value: $viewModel.weightKg,
                    range: 35...220,
                    unit: "kg",
                    symbol: "scalemass"
                )
            case .activity:
                ActivityLevelStep(selectedActivityLevel: $viewModel.activityLevel)
            case .goal:
                GoalSelectionStep(selectedGoal: viewModel.selectedGoal) { goal in
                    viewModel.selectGoal(goal)
                }
            case .pace:
                GoalPaceStep(selectedPace: $viewModel.goalPace)
            case .goalWeight:
                GoalWeightStep(
                    usesGoalWeight: $viewModel.usesGoalWeight,
                    targetWeightKg: $viewModel.targetWeightKg,
                    currentWeightKg: viewModel.weightKg
                )
            case .summary:
                PersonalizedSummaryStep(targets: viewModel.targets, input: viewModel.calculationInput)
            case .health:
                HealthSetupStep(viewModel: viewModel)
            case .premium:
                PremiumIntroStep()
            }
        }
    }
}

private struct WelcomeStepView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            PremiumOnboardingHero(
                symbol: "leaf.circle.fill",
                value: "N",
                caption: "kişisel ritim"
            )

            VStack(spacing: NuvyraSpacing.md) {
                Text("Nuvyra'ya hoş geldin")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.72)

                Text("Sert diyet listeleri yerine beslenme, su ve yürüyüş ritmini sana uygun bir wellness planına dönüştürelim.")
                    .font(.title3.weight(.medium))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    PremiumBullet(title: "Kişisel hedefler", subtitle: "Kalori, protein, karbonhidrat, yağ, su ve adım hedeflerin otomatik hesaplanır.", symbol: "sparkles")
                    PremiumBullet(title: "Wellness dili", subtitle: "Nuvyra suçluluk değil, sürdürülebilir ritim kurar.", symbol: "heart.text.square")
                    PremiumBullet(title: "Privacy-first", subtitle: "Sağlık verisi yalnızca izin verdiğin ölçüde ve uygulama içi içgörüler için kullanılır.", symbol: "lock.shield")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GenderSelectionStep: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selectedGender: Gender

    private let options: [Gender] = [.male, .female, .preferNotToSay]

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Profil",
            title: "Sana en uygun hesaplama için cinsiyet seç.",
            subtitle: "Bu bilgi yalnızca BMR hesaplamasını kişiselleştirmek için kullanılır."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(options) { gender in
                    SelectableOptionCard(
                        title: gender.title,
                        subtitle: gender == .preferNotToSay ? "Nötr formül kullanılır." : "Mifflin-St Jeor formülü bu seçime göre ayarlanır.",
                        symbol: gender.onboardingSymbol,
                        isSelected: selectedGender == gender
                    ) {
                        selectedGender = gender
                    }
                }
            }

            Text("İstersen daha sonra Profil ekranından değiştirebilirsin.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .padding(.horizontal, 2)
        }
    }
}

private struct NumberPickerStep: View {
    @Environment(\.colorScheme) private var scheme
    let eyebrow: String
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let symbol: String

    var body: some View {
        PremiumQuestionLayout(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.lg) {
                    HStack {
                        Image(systemName: symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(NuvyraColors.accent, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(value)")
                                .font(.system(size: 52, weight: .heavy, design: .rounded))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                                .contentTransition(.numericText())
                            Text(unit)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }

                    Picker(title, selection: $value) {
                        ForEach(Array(range), id: \.self) { item in
                            Text("\(item) \(unit)").tag(item)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 154)
                    .clipped()
                    .accessibilityLabel(title)

                    RulerHint()
                }
            }
        }
    }
}

private struct ActivityLevelStep: View {
    @Binding var selectedActivityLevel: ActivityLevel

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Günlük hareket",
            title: "Aktivite seviyeni seç.",
            subtitle: "Nuvyra TDEE hesaplamasında bu katsayıyı kullanır ve adım hedefini buna göre nazikçe ayarlar."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(ActivityLevel.allCases) { level in
                    SelectableOptionCard(
                        title: level.title,
                        subtitle: level.subtitle,
                        symbol: level.symbol,
                        trailingText: "x\(String(format: "%.2f", level.multiplier))",
                        isSelected: selectedActivityLevel == level
                    ) {
                        selectedActivityLevel = level
                    }
                }
            }
        }
    }
}

private struct GoalSelectionStep: View {
    let selectedGoal: GoalType
    let onSelect: (GoalType) -> Void

    private let goals: [GoalType] = [.loseWeight, .maintain, .gainMuscle, .healthyLiving, .stayFit]

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Hedef",
            title: "Nuvyra'yı ne için kullanmak istiyorsun?",
            subtitle: "Hedefin kalori dengesini, protein oranını ve adım önerisini belirler."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(goals) { goal in
                    SelectableOptionCard(
                        title: goal.title,
                        subtitle: goal.onboardingSubtitle,
                        symbol: goal.onboardingSymbol,
                        isSelected: selectedGoal == goal
                    ) {
                        onSelect(goal)
                    }
                }
            }
        }
    }
}

private struct GoalPaceStep: View {
    @Binding var selectedPace: GoalPace

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Tempo",
            title: "İlerleme hızını seç.",
            subtitle: "Nuvyra kalori ayarını bu tempoya göre yapar. Hızlı tempo bile suçlayıcı dile dönüşmez."
        ) {
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(GoalPace.allCases) { pace in
                    SelectableOptionCard(
                        title: pace.title,
                        subtitle: pace.subtitle,
                        symbol: pace.symbol,
                        isSelected: selectedPace == pace
                    ) {
                        selectedPace = pace
                    }
                }
            }
        }
    }
}

private struct GoalWeightStep: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var usesGoalWeight: Bool
    @Binding var targetWeightKg: Int
    let currentWeightKg: Int

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Opsiyonel",
            title: "Hedef kilo eklemek ister misin?",
            subtitle: "Bu alan zorunlu değil. Nuvyra hedefi baskı unsuru değil, yön işareti olarak kullanır."
        ) {
            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hedef kilo")
                                .font(NuvyraTypography.section)
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("İstersen atla; günlük hedeflerin yine kişiselleştirilir.")
                                .font(NuvyraTypography.body)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Hedef kilo kullan", isOn: $usesGoalWeight)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }

                    if usesGoalWeight {
                        VStack(spacing: NuvyraSpacing.md) {
                            Text("\(targetWeightKg) kg")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                                .contentTransition(.numericText())

                            Picker("Hedef kilo", selection: $targetWeightKg) {
                                ForEach(35...220, id: \.self) { item in
                                    Text("\(item) kg").tag(item)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 136)
                            .clipped()
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        SoftNoticeCard(
                            title: "Bunu sonra da ekleyebilirsin.",
                            subtitle: "Şimdilik \(currentWeightKg) kg üzerinden kalori, makro, su ve adım hedefi oluşturacağız.",
                            symbol: "sparkle.magnifyingglass"
                        )
                    }
                }
            }
        }
        .onChange(of: usesGoalWeight) { _, isEnabled in
            if isEnabled {
                targetWeightKg = currentWeightKg
            }
        }
    }
}

private struct PersonalizedSummaryStep: View {
    @Environment(\.colorScheme) private var scheme
    let targets: CalculatedNutritionTargets
    let input: NutritionGoalCalculationInput

    var body: some View {
        VStack(spacing: NuvyraSpacing.lg) {
            PremiumOnboardingHero(
                symbol: "checkmark.seal.fill",
                value: "\(targets.dailyCalories)",
                caption: "kcal / gün"
            )

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Harika. Günlük ritmin hazır.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Nuvyra bu planı Mifflin-St Jeor BMR, aktivite katsayısı ve seçtiğin hedef temposuna göre oluşturdu.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    Label("Kişisel hedeflerin", systemImage: "sparkles")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
                        SummaryMetricCard(title: "Kalori", value: "\(targets.dailyCalories)", unit: "kcal", symbol: "flame.fill", tint: NuvyraColors.mutedCoral)
                        SummaryMetricCard(title: "Protein", value: "\(targets.proteinGrams)", unit: "g", symbol: "bolt.heart.fill", tint: NuvyraColors.accent)
                        SummaryMetricCard(title: "Karbonhidrat", value: "\(targets.carbsGrams)", unit: "g", symbol: "leaf.fill", tint: NuvyraColors.softMint)
                        SummaryMetricCard(title: "Yağ", value: "\(targets.fatGrams)", unit: "g", symbol: "drop.fill", tint: NuvyraColors.softSand)
                        SummaryMetricCard(title: "Su", value: targets.waterLitersText, unit: "", symbol: "drop.circle.fill", tint: NuvyraColors.softMint)
                        SummaryMetricCard(title: "Adım", value: targets.stepTarget.formatted(.number.grouping(.automatic)), unit: "", symbol: "figure.walk", tint: NuvyraColors.paleLime)
                    }

                    Text("Bu değerler wellness hedefidir; tıbbi tanı veya tedavi önerisi değildir. Sağlık durumun veya özel beslenme ihtiyacın varsa profesyonel destek al.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }

            SoftNoticeCard(
                title: "Enerji temeli",
                subtitle: "BMR \(targets.bmr) kcal, aktivite sonrası yaklaşık TDEE \(targets.tdee) kcal. Nuvyra hedefini buradan kişiselleştirdi.",
                symbol: "function"
            )
        }
    }
}

private struct HealthSetupStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        PremiumQuestionLayout(
            eyebrow: "Apple Health",
            title: "Adımların otomatik gelsin.",
            subtitle: "Apple Sağlık iznini açarsan Nuvyra adım ve aktivite ritmini manuel giriş gerektirmeden takip eder."
        ) {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(NuvyraColors.mutedCoral, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(viewModel.healthStatusTitle)
                                .font(NuvyraTypography.section)
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text(viewModel.healthStatusDescription)
                                .font(NuvyraTypography.body)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }

                    if viewModel.healthState == .sharingAuthorized {
                        OnboardingConnectedBadge(title: "Apple Sağlık bağlı")
                    } else {
                        NuvyraSecondaryButton(title: "Apple Sağlık iznini aç", systemImage: "heart") {
                            Task { await viewModel.requestHealth(dependencies: dependencies) }
                        }
                    }

                    Divider().opacity(0.35)

                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(NuvyraColors.accent)
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nazik bildirimler")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("Su, öğün ve akşam yürüyüşünü düşük frekansta hatırlatır.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Nazik bildirimler", isOn: $viewModel.wantsNotifications)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }
                }
            }

            SoftNoticeCard(
                title: "Verilerin sende kalır.",
                subtitle: "Sağlık verileri reklam hedefleme için kullanılmaz. İzinleri iPhone Ayarları'ndan istediğin zaman kapatabilirsin.",
                symbol: "lock.shield"
            )
        }
    }
}

private struct PremiumIntroStep: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            PremiumOnboardingHero(
                symbol: "crown.fill",
                value: "Premium",
                caption: "ritim içgörüleri"
            )

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Daha net trendler. Daha sakin koçluk.")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Premium, günlük takibi baskıya çevirmeden haftalık ritmini daha okunur ve kişisel hale getirir.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.md) {
                    PremiumBullet(title: "Haftalık trendler", subtitle: "Kalori, su ve adım ritmini tek premium özetle gör.", symbol: "chart.line.uptrend.xyaxis")
                    PremiumBullet(title: "Gelişmiş yürüyüş içgörüleri", subtitle: "Düşük günlerde bile uygulanabilir mini toparlanma planları.", symbol: "figure.walk.motion")
                    PremiumBullet(title: "Premium widget deneyimi", subtitle: "Ritmini kilit ekranına ve ana ekrana daha şık taşı.", symbol: "rectangle.on.rectangle")
                }
            }

            Text("Fiyat, deneme ve iptal bilgileri Premium ekranında net şekilde gösterilir.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
    }
}

private struct PremiumQuestionLayout<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(NuvyraColors.accent)

                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct PremiumOnboardingHero: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: String
    let value: String
    let caption: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(heroGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(NuvyraColors.softMint.opacity(scheme == .dark ? 0.24 : 0.38))
                        .frame(width: 210, height: 210)
                        .blur(radius: 38)
                        .offset(x: 72, y: -78)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(NuvyraColors.softSand.opacity(scheme == .dark ? 0.16 : 0.28))
                        .frame(width: 240, height: 240)
                        .blur(radius: 44)
                        .offset(x: -88, y: 84)
                }

            Circle()
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.44), style: StrokeStyle(lineWidth: 1, dash: [8, 11]))
                .frame(width: 222, height: 222)
                .rotationEffect(.degrees(reduceMotion ? 0 : 18))

            VStack(spacing: NuvyraSpacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .heavy))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 20, x: 0, y: 14)

                Text(value)
                    .font(.system(size: value.count > 6 ? 32 : 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)

                Text(caption)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: NuvyraShadow.card(scheme), radius: 28, x: 0, y: 20)
        .accessibilityElement(children: .combine)
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.08, green: 0.10, blue: 0.11), Color(red: 0.04, green: 0.20, blue: 0.17), Color(red: 0.13, green: 0.12, blue: 0.10)]
                : [Color(red: 0.99, green: 0.96, blue: 0.89), Color(red: 0.87, green: 0.97, blue: 0.91), Color(red: 0.94, green: 0.89, blue: 0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SelectableOptionCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let symbol: String
    var trailingText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : NuvyraColors.accent)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: NuvyraSpacing.sm)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(isSelected ? 0.16 : 0.08), in: Capsule())
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.45))
            }
            .padding(16)
            .background(
                isSelected ? NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.11) : NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.50 : 0.72),
                in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                    .stroke(isSelected ? NuvyraColors.accent.opacity(0.45) : Color.white.opacity(scheme == .dark ? 0.08 : 0.36))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityValue(isSelected ? "Seçili" : "Seçili değil")
    }
}

private struct PremiumBullet: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 32, height: 32)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryMetricCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NuvyraColors.card(scheme).opacity(scheme == .dark ? 0.54 : 0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous).stroke(tint.opacity(0.18)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) \(unit)")
    }
}

private struct SoftNoticeCard: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.accent.opacity(scheme == .dark ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RulerHint: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index == 8 || index == 9 ? NuvyraColors.accent : NuvyraColors.secondaryText(scheme).opacity(0.22))
                    .frame(width: 3, height: index % 3 == 0 ? 26 : 14)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

private struct OnboardingConnectedBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(NuvyraColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
    }
}

private struct OnboardingProgressHeader: View {
    @Environment(\.colorScheme) private var scheme
    var progress: Double
    var stepLabel: String

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            HStack {
                Text("Nuvyra")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Spacer()
                Text(stepLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(NuvyraColors.card(scheme).opacity(0.72), in: Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * clampedProgress)
                }
            }
            .frame(height: 7)
            .accessibilityLabel("Onboarding ilerlemesi yüzde \(Int(clampedProgress * 100))")
        }
    }
}

private struct OnboardingControlBar: View {
    @Environment(\.colorScheme) private var scheme
    var canGoBack: Bool
    var primaryTitle: String
    var primaryIcon: String
    var isCompleting: Bool
    var errorMessage: String?
    var onBack: () -> Void
    var onPrimary: () -> Void

    var body: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: NuvyraSpacing.md) {
                if canGoBack {
                    NuvyraSecondaryButton(title: "Geri", systemImage: "chevron.left", action: onBack)
                        .frame(width: 118)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                NuvyraPrimaryButton(title: primaryTitle, systemImage: primaryIcon, action: onPrimary)
                    .disabled(isCompleting)
                    .opacity(isCompleting ? 0.72 : 1)
            }

            Text("Nuvyra wellness uygulamasıdır; tıbbi tanı veya tedavi tavsiyesi vermez.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
                .padding(.top, NuvyraSpacing.xs)
        }
        .padding(.horizontal, NuvyraSpacing.lg)
        .padding(.top, NuvyraSpacing.md)
        .padding(.bottom, NuvyraSpacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.42))
                .frame(height: 1)
        }
    }
}

private extension Gender {
    var onboardingSymbol: String {
        switch self {
        case .male: "person.fill"
        case .female: "person.fill"
        case .other: "person.2.fill"
        case .preferNotToSay: "questionmark.circle.fill"
        }
    }
}

private extension ActivityLevel {
    var symbol: String {
        switch self {
        case .sedentary: "chair.fill"
        case .lightlyActive: "figure.walk"
        case .moderatelyActive: "figure.walk.motion"
        case .veryActive: "figure.run"
        case .athlete: "bolt.heart.fill"
        }
    }
}

private extension GoalPace {
    var symbol: String {
        switch self {
        case .slow: "tortoise.fill"
        case .balanced: "equal.circle.fill"
        case .fast: "hare.fill"
        }
    }
}

private extension GoalType {
    var onboardingSubtitle: String {
        switch self {
        case .loseWeight:
            "Nazik kalori açığı, yüksek protein ve gerçekçi adım hedefi."
        case .maintain:
            "Enerji dengesini koruyan sakin günlük ritim."
        case .gainHealthy:
            "Daha yüksek enerji hedefiyle sağlıklı kilo artışı."
        case .gainMuscle:
            "Protein odağı yüksek, kontrollü kalori fazlası."
        case .walkMore:
            "Walking-first planla adımı alışkanlığa çevir."
        case .eatHealthier:
            "Öğün farkındalığını sade ve sürdürülebilir artır."
        case .healthyLiving:
            "Beslenme, su ve hareket dengesini bütünsel kur."
        case .stayFit:
            "Formunu korurken adım ve makro ritmini netleştir."
        }
    }

    var onboardingSymbol: String {
        switch self {
        case .loseWeight: "arrow.down.forward.circle.fill"
        case .maintain: "equal.circle.fill"
        case .gainHealthy: "plus.circle.fill"
        case .gainMuscle: "dumbbell.fill"
        case .walkMore: "figure.walk.circle.fill"
        case .eatHealthier: "leaf.circle.fill"
        case .healthyLiving: "heart.circle.fill"
        case .stayFit: "sparkles"
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
