import Foundation
import SwiftData

/// Daily body snapshot — at minimum holds weight, but optionally carries the
/// full body-composition picture (circumferences + body fat %). All new fields
/// are optional so SwiftData applies a lightweight migration on existing stores.
@Model
final class WeightLog: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double
    var source: String
    var note: String?
    var createdAt: Date

    // MARK: - Body composition (optional, added in v1.1)
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var shoulderCm: Double?
    var neckCm: Double?
    var bicepCm: Double?
    var thighCm: Double?
    var bodyFatPercent: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weightKg: Double,
        source: String = "manual",
        note: String? = nil,
        createdAt: Date = Date(),
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        shoulderCm: Double? = nil,
        neckCm: Double? = nil,
        bicepCm: Double? = nil,
        thighCm: Double? = nil,
        bodyFatPercent: Double? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.weightKg = weightKg
        self.source = source
        self.note = note
        self.createdAt = createdAt
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.shoulderCm = shoulderCm
        self.neckCm = neckCm
        self.bicepCm = bicepCm
        self.thighCm = thighCm
        self.bodyFatPercent = bodyFatPercent
    }

    /// Convenience — true when *any* body-composition field is filled.
    var hasBodyComposition: Bool {
        waistCm != nil || hipCm != nil || chestCm != nil || shoulderCm != nil ||
        neckCm != nil || bicepCm != nil || thighCm != nil || bodyFatPercent != nil
    }

    /// Waist-to-hip ratio — a commonly tracked composition metric.
    var waistToHipRatio: Double? {
        guard let w = waistCm, let h = hipCm, h > 0 else { return nil }
        return w / h
    }
}
