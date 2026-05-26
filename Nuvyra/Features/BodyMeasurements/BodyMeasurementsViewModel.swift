import Combine
import Foundation
import SwiftData

@MainActor
final class BodyMeasurementsViewModel: ObservableObject {
    @Published var history: [WeightLog] = []
    @Published var latest: WeightLog?
    @Published var selectedMetric: BodyMeasurementTrendCard.Metric = .weight
    @Published var editingLog: WeightLog?
    @Published var showingAdd = false
    @Published var errorMessage: String?

    /// Range options surfaced in the picker chips (in days).
    let ranges: [(label: String, days: Int)] = [
        ("30G", 30), ("90G", 90), ("6A", 180), ("1Y", 365)
    ]
    @Published var selectedDays: Int = 90

    var availableMetrics: [BodyMeasurementTrendCard.Metric] {
        // Always show weight; only show body-composition metrics that have at least one data point.
        var list: [BodyMeasurementTrendCard.Metric] = [.weight]
        let probe: [(BodyMeasurementTrendCard.Metric, (WeightLog) -> Double?)] = [
            (.waist, { $0.waistCm }),
            (.hip, { $0.hipCm }),
            (.chest, { $0.chestCm }),
            (.shoulder, { $0.shoulderCm }),
            (.neck, { $0.neckCm }),
            (.bicep, { $0.bicepsCm }),
            (.thigh, { $0.thighCm }),
            (.bodyFat, { $0.bodyFatPercent }),
            (.waistHipRatio, { $0.waistToHipRatio })
        ]
        for (metric, accessor) in probe {
            if history.contains(where: { accessor($0) != nil }) {
                list.append(metric)
            }
        }
        return list
    }

    var hasAnyBodyComposition: Bool {
        history.contains(where: { $0.hasBodyComposition })
    }

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.weightRepository(context: context)
            history = try repository.logs(days: selectedDays)
            latest = try repository.latestBodyMeasurement()
            // If the previously selected metric has no data, fall back to weight.
            if !availableMetrics.contains(selectedMetric) { selectedMetric = .weight }
        } catch {
            errorMessage = "Vücut ölçüleri yüklenemedi."
        }
    }

    func changeRange(days: Int, context: ModelContext, dependencies: DependencyContainer) {
        selectedDays = days
        load(context: context, dependencies: dependencies)
    }

    func delete(_ log: WeightLog, context: ModelContext, dependencies: DependencyContainer) {
        do {
            try dependencies.weightRepository(context: context).deleteMeasurement(log)
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Ölçüm silinemedi."
        }
    }

    func startEditing(_ log: WeightLog) {
        editingLog = log
    }
}
