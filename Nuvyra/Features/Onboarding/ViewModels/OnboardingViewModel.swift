import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var stepIndex = 0
    @Published var selectedGoal: WellnessGoal = .buildHealthRhythm
    @Published var age = 31
    @Published var heightCentimeters = 174
    @Published var weightKilograms = 78
    @Published var targetWeightKilograms = 74
    @Published var gender: GenderOption = .preferNotToSay
    @Published var activityLevel: ActivityLevel = .light
    @Published var mealsPerDay = 3
    @Published var difficultMoment: DifficultMoment = .evening
    @Published var preferredWalkTime: WalkTimePreference = .afterDinner
    @Published var wantsReminders = true
    @Published var healthPermissionStatus: HealthAuthorizationStatus?
    @Published var notificationPermissionStatus: NotificationPermissionStatus?

    let steps = OnboardingStep.allCases
    private let calorieCalculator = CalorieTargetCalculator()

    var currentStep: OnboardingStep { steps[stepIndex] }
    var isFirstStep: Bool { stepIndex == 0 }
    var isLastStep: Bool { stepIndex == steps.count - 1 }

    var previewProfile: UserProfile {
        makeProfile()
    }

    var target: CalorieTarget {
        calorieCalculator.target(for: previewProfile)
    }

    var startingStepGoal: Int {
        StepGoalAdapter().initialGoal(for: activityLevel)
    }

    func moveNext() {
        guard !isLastStep else { return }
        stepIndex += 1
    }

    func moveBack() {
        guard !isFirstStep else { return }
        stepIndex -= 1
    }

    func makeProfile() -> UserProfile {
        UserProfile(
            goal: selectedGoal,
            age: age,
            heightCentimeters: heightCentimeters,
            weightKilograms: Double(weightKilograms),
            targetWeightKilograms: Double(targetWeightKilograms),
            gender: gender,
            activityLevel: activityLevel,
            routine: DailyRoutine(
                mealsPerDay: mealsPerDay,
                difficultMoment: difficultMoment,
                preferredWalkTime: preferredWalkTime,
                wantsReminders: wantsReminders
            )
        )
    }
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case goal
    case profile
    case routine
    case valueMoment
    case healthKit
    case notifications
    case premium

    var id: Int { rawValue }

    var progressTitle: String {
        switch self {
        case .welcome: "Başlangıç"
        case .goal: "Hedef"
        case .profile: "Profil"
        case .routine: "Rutin"
        case .valueMoment: "İlk plan"
        case .healthKit: "Apple Sağlık"
        case .notifications: "Bildirim"
        case .premium: "Premium"
        }
    }
}
