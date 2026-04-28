import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(spacing: NuvyraSpacing.lg) {
                progressHeader
                TabView(selection: $viewModel.stepIndex) {
                    WelcomeStepView().tag(OnboardingStep.welcome.rawValue)
                    GoalStepView(viewModel: viewModel).tag(OnboardingStep.goal.rawValue)
                    ProfileStepView(viewModel: viewModel).tag(OnboardingStep.profile.rawValue)
                    RoutineStepView(viewModel: viewModel).tag(OnboardingStep.routine.rawValue)
                    ValueMomentStepView(viewModel: viewModel).tag(OnboardingStep.valueMoment.rawValue)
                    HealthKitStepView(viewModel: viewModel).tag(OnboardingStep.healthKit.rawValue)
                    NotificationStepView(viewModel: viewModel).tag(OnboardingStep.notifications.rawValue)
                    PremiumStepView().tag(OnboardingStep.premium.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(NuvyraMotion.gentle(reduceMotion: reduceMotion), value: viewModel.stepIndex)

                navigationBar
            }
            .padding(.horizontal, NuvyraSpacing.lg)
            .padding(.vertical, NuvyraSpacing.md)
        }
        .task {
            await appState.environment.analytics.track(AnalyticsEvent(.onboardingStarted))
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            HStack {
                Text(viewModel.currentStep.progressTitle)
                    .font(NuvyraTypography.caption().weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.stepIndex + 1)/\(viewModel.steps.count)")
                    .font(NuvyraTypography.caption().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(viewModel.stepIndex + 1), total: Double(viewModel.steps.count))
                .tint(NuvyraColor.lightPrimary)
        }
        .padding(.top, NuvyraSpacing.sm)
    }

    private var navigationBar: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            if !viewModel.isFirstStep {
                NuvyraSecondaryButton(title: "Geri", systemImage: "chevron.left") {
                    viewModel.moveBack()
                }
                .frame(maxWidth: 130)
            }

            NuvyraPrimaryButton(
                title: viewModel.isLastStep ? "Ritmime başla" : "Devam",
                systemImage: viewModel.isLastStep ? "checkmark" : "arrow.right"
            ) {
                if viewModel.isLastStep {
                    Task { await appState.completeOnboarding(profile: viewModel.makeProfile()) }
                } else {
                    if viewModel.currentStep == .goal {
                        Task { await appState.environment.analytics.track(AnalyticsEvent(.goalSelected, payload: ["goal_type": viewModel.selectedGoal.analyticsValue])) }
                    }
                    viewModel.moveNext()
                }
            }
        }
    }
}

private struct WelcomeStepView: View {
    var body: some View {
        OnboardingPage {
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                Text("Katı diyet değil, sürdürülebilir ritim.")
                    .font(NuvyraTypography.hero())
                    .foregroundStyle(.primary)
                Text("Nuvyra öğünlerini, adımlarını ve günlük hedeflerini tek bir sade akışta toplar.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                NuvyraGlassCard {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Label("Wellness ve fitness koçu", systemImage: "heart.text.square")
                            .font(.headline)
                        Text("Nuvyra tıbbi teşhis veya tedavi sunmaz. Kalori ve besin değerleri tahminidir; özel sağlık durumlarında profesyonel destek almalısın.")
                            .font(NuvyraTypography.body())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}

private struct GoalStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingPage(title: "Bugün en çok neyi kolaylaştırmak istiyorsun?", subtitle: "Tek bir hedef seç; planı nazikçe buna göre başlatalım.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: NuvyraSpacing.sm)], spacing: NuvyraSpacing.sm) {
                ForEach(WellnessGoal.allCases) { goal in
                    NuvyraChip(title: goal.title, isSelected: viewModel.selectedGoal == goal) {
                        viewModel.selectedGoal = goal
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ProfileStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingPage(title: "Planın gerçekçi olsun", subtitle: "Bu bilgiler cihazında saklanır ve hedef aralığını hesaplamak için kullanılır.") {
            NuvyraGlassCard {
                VStack(spacing: NuvyraSpacing.md) {
                    Stepper("Yaş: \(viewModel.age)", value: $viewModel.age, in: 16...85)
                    Stepper("Boy: \(viewModel.heightCentimeters) cm", value: $viewModel.heightCentimeters, in: 130...220)
                    Stepper("Kilo: \(viewModel.weightKilograms) kg", value: $viewModel.weightKilograms, in: 40...180)
                    Stepper("Hedef kilo: \(viewModel.targetWeightKilograms) kg", value: $viewModel.targetWeightKilograms, in: 40...180)
                    Picker("Cinsiyet", selection: $viewModel.gender) {
                        ForEach(GenderOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("Aktivite", selection: $viewModel.activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                }
            }
        }
    }
}

private struct RoutineStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingPage(title: "Günün ritmini tanıyalım", subtitle: "Bildirimler satış için değil, ritmini nazikçe hatırlatmak için kullanılacak.") {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    Stepper("Genelde \(viewModel.mealsPerDay) öğün", value: $viewModel.mealsPerDay, in: 1...6)
                    Picker("En zorlandığın zaman", selection: $viewModel.difficultMoment) {
                        ForEach(DifficultMoment.allCases) { moment in
                            Text(moment.title).tag(moment)
                        }
                    }
                    Picker("Yürüyüş için uygun zaman", selection: $viewModel.preferredWalkTime) {
                        ForEach(WalkTimePreference.allCases) { time in
                            Text(time.title).tag(time)
                        }
                    }
                    Toggle("Nazik hatırlatmalar istiyorum", isOn: $viewModel.wantsReminders)
                }
            }
        }
    }
}

private struct ValueMomentStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingPage(title: "İlk planın hazır", subtitle: "Bugün kusursuz olmak zorunda değil. Başlangıç hedefi sürdürülebilir olmalı.") {
            HStack(spacing: NuvyraSpacing.md) {
                NuvyraMetricCard(title: "Kalori aralığı", value: viewModel.target.displayRange, detail: "Tahmini günlük aralık", systemImage: "flame")
                NuvyraMetricCard(title: "Adım hedefi", value: viewModel.startingStepGoal.formatted(), detail: "Başlangıç için yeterli", systemImage: "figure.walk")
            }
            NuvyraGlassCard {
                Text("Bugün için hedefin 10.000 adım olmak zorunda değil. Başlangıç için \(viewModel.startingStepGoal.formatted()) adım yeterli.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HealthKitStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OnboardingPage {
            NuvyraPermissionCard(
                title: "Adımlarını otomatik alalım mı?",
                bodyText: "Apple Sağlık bağlantısı sadece adımlarını okumak için kullanılır. İstediğin zaman kapatabilirsin.",
                systemImage: "heart.text.square",
                primaryTitle: viewModel.healthPermissionStatus == .granted ? "Bağlandı" : "Apple Sağlık iznini aç",
                secondaryTitle: "Şimdilik geç",
                primaryAction: {
                    Task { viewModel.healthPermissionStatus = await appState.requestHealthKitSteps() }
                },
                secondaryAction: {
                    viewModel.healthPermissionStatus = .denied
                }
            )
        }
    }
}

private struct NotificationStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OnboardingPage {
            NuvyraPermissionCard(
                title: "Seni rahatsız etmeyen hatırlatmalar",
                bodyText: "Öğün, su ve kısa yürüyüş hatırlatmalarını ilk günden abartmadan planlarız.",
                systemImage: "bell.badge",
                primaryTitle: viewModel.notificationPermissionStatus == .granted ? "Bildirimler açık" : "Bildirim iznini aç",
                secondaryTitle: "Şimdilik geç",
                primaryAction: {
                    Task {
                        viewModel.notificationPermissionStatus = await appState.requestNotifications()
                        await appState.scheduleGentleReminders()
                    }
                },
                secondaryAction: {
                    viewModel.notificationPermissionStatus = .denied
                }
            )
        }
    }
}

private struct PremiumStepView: View {
    var body: some View {
        OnboardingPage(title: "Premium, ritmini daha görünür yapar", subtitle: "Paywall agresif değildir; fiyat ve iptal bilgisi App Store ekranında açıkça görünür.") {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    NuvyraPaywallFeatureRow(title: "Sınırsız fotoğraflı öğün kaydı")
                    NuvyraPaywallFeatureRow(title: "Adaptif yürüyüş planı")
                    NuvyraPaywallFeatureRow(title: "Haftalık koç özeti")
                    Divider()
                    Text("Aboneliği istediğin zaman Apple ID ayarlarından iptal edebilirsin. Restore Purchases her zaman Ayarlar ve Paywall içinde bulunur.")
                        .font(NuvyraTypography.caption())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct OnboardingPage<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                if let title {
                    Text(title)
                        .font(NuvyraTypography.title())
                }
                if let subtitle {
                    Text(subtitle)
                        .font(NuvyraTypography.body())
                        .foregroundStyle(.secondary)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, NuvyraSpacing.lg)
        }
    }
}

struct NuvyraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            NuvyraColor.background(for: colorScheme).ignoresSafeArea()
            Circle()
                .fill(NuvyraColor.primary(for: colorScheme).opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: -140, y: -260)
            Circle()
                .fill(NuvyraColor.accent(for: colorScheme).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 48)
                .offset(x: 150, y: 260)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.preview(completedOnboarding: false))
}
