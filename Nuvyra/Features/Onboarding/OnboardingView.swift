import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            OnboardingMeshBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, NuvyraSpacing.lg)
                    .padding(.top, NuvyraSpacing.sm)

                ScrollView(showsIndicators: false) {
                    stepContent
                        .id(viewModel.currentStep.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.top, NuvyraSpacing.lg)
                        .padding(.bottom, 220)
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: viewModel.pageIndex)
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .task { await dependencies.analytics.track(.onboardingStarted, payload: AnalyticsPayload()) }
        .alert("Başlangıç tamamlanamadı", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Lütfen tekrar dene.")
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: NuvyraSpacing.md) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.back()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(NuvyraColors.accent.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .opacity(viewModel.pageIndex > 0 ? 1 : 0)
            .accessibilityLabel("Geri")

            OnboardingProgressDots(currentIndex: viewModel.pageIndex, total: viewModel.totalStepsCount)

            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var footer: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }

            OnboardingContinueButton(
                title: viewModel.primaryButtonTitle,
                systemImage: viewModel.primaryButtonIcon,
                isEnabled: viewModel.canContinue,
                isLoading: viewModel.isCompleting
            ) {
                if viewModel.isLastPage {
                    Task { await viewModel.complete(context: modelContext, dependencies: dependencies) }
                } else {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
                        viewModel.next()
                    }
                }
            }

            Text("Nuvyra wellness uygulamasıdır; tıbbi tanı veya tedavi tavsiyesi vermez.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, NuvyraSpacing.lg)
        .padding(.top, NuvyraSpacing.md)
        .padding(.bottom, NuvyraSpacing.md)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome: WelcomeStep()
        case .gender: GenderStep(selected: $viewModel.selectedGender)
        case .age: NumberRulerStep(eyebrow: "Profil", title: "Yaşını seç.", subtitle: "Günlük enerji hedefini yaşına göre kişiselleştirelim.", value: $viewModel.age, range: 13...100, unit: "yaş", symbol: "calendar")
        case .height: NumberRulerStep(eyebrow: "Vücut", title: "Boyunu seç.", subtitle: "BMR ve günlük su hedefin santimetre üzerinden ayarlanır.", value: $viewModel.heightCm, range: 130...220, unit: "cm", symbol: "ruler")
        case .weight: NumberRulerStep(eyebrow: "Vücut", title: "Kilonu seç.", subtitle: "Kalori, makro ve su hedeflerinin temelini bu değer oluşturur.", value: $viewModel.weightKg, range: 35...220, unit: "kg", symbol: "scalemass")
        case .activity: ActivityStep(selected: $viewModel.activityLevel)
        case .goal: GoalStep(selected: viewModel.selectedGoal) { viewModel.selectGoal($0) }
        case .pace: PaceStep(selected: $viewModel.goalPace)
        case .goalWeight: GoalWeightRulerStep(uses: $viewModel.usesGoalWeight, target: $viewModel.targetWeightKg, currentWeight: viewModel.weightKg)
        case .summary: SummaryStep(targets: viewModel.targets)
        case .health: HealthStep(viewModel: viewModel)
        case .premium: PremiumIntroStep()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    @Environment(\.colorScheme) private var scheme
    @State private var visible = false

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            OnboardingHeroHalo(systemImage: "leaf.fill")
                .frame(height: 280)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 24)

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Nuvyra'ya hoş geldin")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 20)

                Text("Sert diyet listeleri yerine kendi ritmine uygun, sürdürülebilir bir wellness planı kuralım.")
                    .font(.title3.weight(.medium))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 22)
            }

            VStack(spacing: NuvyraSpacing.sm) {
                WelcomeBullet(symbol: "sparkles", title: "Kişisel hedefler", subtitle: "Kalori, protein, su ve adım hedeflerin otomatik hesaplanır.")
                WelcomeBullet(symbol: "heart.text.square", title: "Wellness dili", subtitle: "Suçluluk değil, sürdürülebilir ritim odaklı.")
                WelcomeBullet(symbol: "lock.shield", title: "Privacy-first", subtitle: "Sağlık verisi yalnızca uygulama içi içgörüler için kullanılır.")
            }
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) { visible = true }
        }
    }
}

private struct WelcomeBullet: View {
    @Environment(\.colorScheme) private var scheme
    var symbol: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 6, x: 0, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.32))
        )
    }
}

// MARK: - Gender

private struct GenderStep: View {
    @Binding var selected: Gender

    private let options: [Gender] = [.male, .female, .preferNotToSay]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Profil", title: "Sana en uygun hesaplama için seçim yap.", subtitle: "Bu bilgi yalnızca BMR formülünü kişiselleştirmek için kullanılır.")
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(options) { gender in
                    OnboardingSelectableTile(
                        title: gender.title,
                        subtitle: gender == .preferNotToSay ? "Nötr formül kullanılır." : "Mifflin-St Jeor formülü bu seçime göre ayarlanır.",
                        symbol: gender.onboardingSymbol,
                        isSelected: selected == gender
                    ) {
                        selected = gender
                    }
                }
            }
        }
    }
}

// MARK: - Number ruler step (age / height / weight)

private struct NumberRulerStep: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var unit: String
    var symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: eyebrow, title: title, subtitle: subtitle)

            NuvyraGlassCard {
                OnboardingRulerPicker(value: $value, range: range, unit: unit, symbol: symbol)
            }
        }
    }
}

// MARK: - Activity

private struct ActivityStep: View {
    @Binding var selected: ActivityLevel

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Hareket", title: "Aktivite seviyeni seç.", subtitle: "Nuvyra TDEE hesaplamasında bu katsayıyı kullanır ve adım hedefini ayarlar.")
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(ActivityLevel.allCases) { level in
                    OnboardingSelectableTile(
                        title: level.title,
                        subtitle: level.subtitle,
                        symbol: level.symbol,
                        trailingText: "x\(String(format: "%.2f", level.multiplier))",
                        isSelected: selected == level
                    ) {
                        selected = level
                    }
                }
            }
        }
    }
}

// MARK: - Goal

private struct GoalStep: View {
    var selected: GoalType
    var onSelect: (GoalType) -> Void

    private let goals: [GoalType] = [.loseWeight, .maintain, .gainMuscle, .healthyLiving, .stayFit]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Hedef", title: "Nuvyra'yı ne için kullanmak istiyorsun?", subtitle: "Hedefin kalori dengesini, protein oranını ve adım önerisini belirler.")
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(goals) { goal in
                    OnboardingSelectableTile(
                        title: goal.title,
                        subtitle: goal.onboardingSubtitle,
                        symbol: goal.onboardingSymbol,
                        isSelected: selected == goal
                    ) {
                        onSelect(goal)
                    }
                }
            }
        }
    }
}

// MARK: - Pace

private struct PaceStep: View {
    @Binding var selected: GoalPace

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Tempo", title: "İlerleme hızını seç.", subtitle: "Nuvyra kalori ayarını bu tempoya göre yapar. Hızlı tempo bile suçlayıcı dile dönüşmez.")
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(GoalPace.allCases) { pace in
                    OnboardingSelectableTile(
                        title: pace.title,
                        subtitle: pace.subtitle,
                        symbol: pace.symbol,
                        isSelected: selected == pace
                    ) {
                        selected = pace
                    }
                }
            }
        }
    }
}

// MARK: - Goal weight (optional)

private struct GoalWeightRulerStep: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var uses: Bool
    @Binding var target: Int
    let currentWeight: Int

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Opsiyonel", title: "Hedef kilo eklemek ister misin?", subtitle: "Bu alan zorunlu değil. Nuvyra hedefi baskı unsuru değil, yön işareti olarak kullanır.")

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hedef kilo")
                                .font(.subheadline.weight(.bold))
                            Text("İstersen atla; günlük hedeflerin yine kişiselleştirilir.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Hedef kilo kullan", isOn: $uses)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }

                    if uses {
                        OnboardingRulerPicker(value: $target, range: 35...220, unit: "kg", symbol: "scalemass")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        InfoCard(
                            symbol: "sparkle.magnifyingglass",
                            title: "Bunu sonra da ekleyebilirsin.",
                            subtitle: "Şimdilik \(currentWeight) kg üzerinden kalori, makro, su ve adım hedefi oluşturacağız."
                        )
                    }
                }
            }
        }
        .onChange(of: uses) { _, isEnabled in
            if isEnabled { target = currentWeight }
        }
    }
}

// MARK: - Summary

private struct SummaryStep: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let targets: CalculatedNutritionTargets
    @State private var ringProgress: Double = 0
    @State private var sparkle = false

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            ZStack {
                Circle()
                    .stroke(NuvyraColors.accent.opacity(0.12), lineWidth: 20)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: NuvyraColors.accent.opacity(0.3), radius: 14)
                VStack(spacing: 4) {
                    Text("\(targets.dailyCalories)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(targets.dailyCalories)))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text("kcal / gün")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                if sparkle {
                    SparkleParticles()
                }
            }
            .frame(width: 220, height: 220)

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Günlük ritmin hazır.")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                Text("Nuvyra bu planı Mifflin-St Jeor BMR, aktivite katsayısı ve seçtiğin tempoya göre oluşturdu.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
                OnboardingMetricBadge(title: "Protein", value: "\(targets.proteinGrams)", unit: "g", symbol: "bolt.heart.fill", tint: NuvyraColors.mutedCoral)
                OnboardingMetricBadge(title: "Karbonhidrat", value: "\(targets.carbsGrams)", unit: "g", symbol: "leaf.fill", tint: NuvyraColors.paleLime)
                OnboardingMetricBadge(title: "Yağ", value: "\(targets.fatGrams)", unit: "g", symbol: "drop.fill", tint: NuvyraColors.softSand)
                OnboardingMetricBadge(title: "Su", value: targets.waterLitersText, unit: nil, symbol: "drop.circle.fill", tint: Color(red: 0.30, green: 0.70, blue: 0.95))
                OnboardingMetricBadge(title: "Adım", value: targets.stepTarget.formatted(.number.grouping(.automatic)), unit: nil, symbol: "figure.walk", tint: NuvyraColors.accent)
                OnboardingMetricBadge(title: "BMR", value: "\(targets.bmr)", unit: "kcal", symbol: "function", tint: NuvyraColors.softMint)
            }

            InfoCard(
                symbol: "info.circle",
                title: "Bilgilendirme",
                subtitle: "Bu değerler wellness hedefidir; tıbbi tanı veya tedavi önerisi değildir. Sağlık durumun varsa uzmana danış."
            )
        }
        .onAppear {
            if reduceMotion {
                ringProgress = 1
            } else {
                withAnimation(.easeOut(duration: 1.2).delay(0.1)) { ringProgress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { sparkle = true }
            }
        }
    }
}

private struct SparkleParticles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(NuvyraColors.softSand)
                    .offset(
                        x: cos(Double(index) * .pi / 5 + phase) * 130,
                        y: sin(Double(index) * .pi / 5 + phase) * 130
                    )
                    .opacity(0.7)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Health

private struct HealthStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            OnboardingEyebrow(eyebrow: "Apple Sağlık", title: "Adımların otomatik gelsin.", subtitle: "Apple Sağlık iznini açarsan Nuvyra adım ve aktivite ritmini manuel giriş gerektirmeden takip eder.")

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [NuvyraColors.mutedCoral, NuvyraColors.softSand], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 52, height: 52)
                                .shadow(color: NuvyraColors.mutedCoral.opacity(0.3), radius: 10, x: 0, y: 6)
                            Image(systemName: "heart.text.square.fill")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.healthStatusTitle)
                                .font(.subheadline.weight(.bold))
                            Text(viewModel.healthStatusDescription)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if viewModel.healthState == .sharingAuthorized {
                        Label("Apple Sağlık bağlı", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                    } else {
                        NuvyraSecondaryButton(title: "Apple Sağlık iznini aç", systemImage: "heart") {
                            Task { await viewModel.requestHealth(dependencies: dependencies) }
                        }
                    }

                    Divider().opacity(0.32)

                    HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(NuvyraColors.accent)
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nazik bildirimler")
                                .font(.subheadline.weight(.bold))
                            Text("Su, öğün ve akşam yürüyüşünü düşük frekansta hatırlatır.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }

                        Spacer()

                        Toggle("Nazik bildirimler", isOn: $viewModel.wantsNotifications)
                            .labelsHidden()
                            .tint(NuvyraColors.accent)
                    }
                }
            }

            InfoCard(
                symbol: "lock.shield",
                title: "Verilerin sende kalır.",
                subtitle: "Sağlık verileri reklam hedefleme için kullanılmaz. İzinleri iPhone Ayarları'ndan istediğin zaman kapatabilirsin."
            )
        }
    }
}

// MARK: - Premium

private struct PremiumIntroStep: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: NuvyraSpacing.xl) {
            OnboardingHeroHalo(systemImage: "crown.fill", tint: NuvyraColors.softSand, secondary: NuvyraColors.accent)
                .frame(height: 260)

            VStack(spacing: NuvyraSpacing.sm) {
                Text("Daha net trendler.\nDaha sakin koçluk.")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Premium, günlük takibi baskıya çevirmeden haftalık ritmini daha okunur ve kişisel hale getirir.")
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .frame(maxWidth: 360)
            }

            VStack(spacing: NuvyraSpacing.sm) {
                WelcomeBullet(symbol: "chart.line.uptrend.xyaxis", title: "Haftalık trendler", subtitle: "Kalori, su ve adım ritmini tek premium özetle gör.")
                WelcomeBullet(symbol: "figure.walk.motion", title: "Yürüyüş içgörüleri", subtitle: "Düşük günlerde uygulanabilir mini toparlanma planları.")
                WelcomeBullet(symbol: "rectangle.on.rectangle", title: "Premium widget", subtitle: "Ritmini kilit ekranı ve ana ekrana daha şık taşı.")
            }

            Text("Fiyat, deneme ve iptal bilgileri Premium ekranında net şekilde gösterilir.")
                .font(.caption.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Shared info card

private struct InfoCard: View {
    @Environment(\.colorScheme) private var scheme
    var symbol: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 32, height: 32)
                .background(NuvyraColors.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.accent.opacity(scheme == .dark ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Symbol extensions

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
        case .loseWeight: "Nazik kalori açığı, yüksek protein ve gerçekçi adım hedefi."
        case .maintain: "Enerji dengesini koruyan sakin günlük ritim."
        case .gainHealthy: "Daha yüksek enerji hedefiyle sağlıklı kilo artışı."
        case .gainMuscle: "Protein odağı yüksek, kontrollü kalori fazlası."
        case .walkMore: "Walking-first planla adımı alışkanlığa çevir."
        case .eatHealthier: "Öğün farkındalığını sade ve sürdürülebilir artır."
        case .healthyLiving: "Beslenme, su ve hareket dengesini bütünsel kur."
        case .stayFit: "Formunu korurken adım ve makro ritmini netleştir."
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
