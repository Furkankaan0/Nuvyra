import HealthKit
import SwiftUI
import WatchKit

struct WatchDashboardView: View {
    @EnvironmentObject private var session: WatchConnectivityBridge
    @StateObject private var viewModel = WatchDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    metricCard(
                        title: "Su",
                        value: "\(viewModel.waterMl) ml",
                        subtitle: "Bugün",
                        systemImage: "drop.fill",
                        progress: viewModel.waterProgress
                    )

                    HStack(spacing: 8) {
                        waterButton(amount: 250)
                        waterButton(amount: 500)
                    }

                    metricCard(
                        title: "Adımlar",
                        value: viewModel.steps.formatted(),
                        subtitle: viewModel.healthStatus,
                        systemImage: "figure.walk",
                        progress: viewModel.stepProgress
                    )

                    if !session.isReachable {
                        Label("iPhone çevrimdışıysa su kaydı eşitlenmek üzere bekletilir.", systemImage: "iphone.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Nuvyra")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Yenile")
                }
            }
            .task { await viewModel.refresh() }
        }
    }

    private func waterButton(amount: Int) -> some View {
        Button {
            let total = viewModel.addWater(amount)
            session.sendWater(amountMl: amount, totalMl: total)
            WKInterfaceDevice.current().play(.click)
        } label: {
            Label("+\(amount) ml", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.weight(.bold))

            ProgressView(value: progress)
                .tint(.cyan)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@MainActor
final class WatchDashboardViewModel: ObservableObject {
    @Published private(set) var waterMl = 0
    @Published private(set) var steps = 0
    @Published private(set) var healthStatus = "Apple Health"

    private let healthStore = HKHealthStore()
    private let waterKey = "watch.today.waterMl"
    private let dayKey = "watch.today.waterDay"
    private let waterTarget = 2_000
    private let stepTarget = 7_500

    var waterProgress: Double {
        min(Double(waterMl) / Double(waterTarget), 1)
    }

    var stepProgress: Double {
        min(Double(steps) / Double(stepTarget), 1)
    }

    func refresh() async {
        loadWater()
        steps = await fetchSteps()
    }

    func addWater(_ amount: Int) -> Int {
        loadWater()
        waterMl += amount
        UserDefaults.standard.set(waterMl, forKey: waterKey)
        UserDefaults.standard.set(dayStamp, forKey: dayKey)
        return waterMl
    }

    private func loadWater() {
        if UserDefaults.standard.string(forKey: dayKey) != dayStamp {
            waterMl = 0
            UserDefaults.standard.set(0, forKey: waterKey)
            UserDefaults.standard.set(dayStamp, forKey: dayKey)
            return
        }
        waterMl = UserDefaults.standard.integer(forKey: waterKey)
    }

    private var dayStamp: String {
        Date().formatted(.iso8601.year().month().day())
    }

    private func fetchSteps() async -> Int {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            healthStatus = "Health uygun değil"
            return 0
        }

        let authorized = await requestStepAuthorizationIfNeeded(stepType)
        guard authorized else { return 0 }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                Task { @MainActor in
                    self?.healthStatus = "Watch Health"
                    continuation.resume(returning: Int(value.rounded()))
                }
            }
            healthStore.execute(query)
        }
    }

    private func requestStepAuthorizationIfNeeded(_ stepType: HKQuantityType) async -> Bool {
        switch healthStore.authorizationStatus(for: stepType) {
        case .sharingAuthorized:
            healthStatus = "Watch Health"
            return true
        case .sharingDenied:
            healthStatus = "Health izni kapalı"
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                healthStore.requestAuthorization(toShare: [], read: [stepType]) { [weak self] success, _ in
                    Task { @MainActor in
                        self?.healthStatus = success ? "Watch Health" : "Health izni kapalı"
                        continuation.resume(returning: success)
                    }
                }
            }
        @unknown default:
            healthStatus = "Health durumu bilinmiyor"
            return false
        }
    }
}

#Preview {
    WatchDashboardView()
        .environmentObject(WatchConnectivityBridge.shared)
}
