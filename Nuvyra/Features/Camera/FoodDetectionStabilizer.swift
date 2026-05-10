import Foundation

/// Smooths jumpy per-frame detections by accumulating votes across a sliding
/// window and only surfacing labels that have appeared in at least
/// `minOccurrences` of the last `windowSize` frames. The exposed list is sorted
/// by smoothed confidence (mean confidence × occurrence ratio).
final class FoodDetectionStabilizer {
    struct Stable: Equatable {
        let label: String
        let smoothedConfidence: Float
        let lastBoundingBox: CGRect
        let occurrences: Int
    }

    private let windowSize: Int
    private let minOccurrences: Int
    private let topRawPerFrame: Int
    private var window: [[CameraDetection]] = []

    init(windowSize: Int = 6, minOccurrences: Int = 3, topRawPerFrame: Int = 4) {
        self.windowSize = max(windowSize, 1)
        self.minOccurrences = max(min(minOccurrences, windowSize), 1)
        self.topRawPerFrame = max(topRawPerFrame, 1)
    }

    @discardableResult
    func ingest(_ detections: [CameraDetection]) -> [Stable] {
        let trimmed = Array(detections.sorted { $0.confidence > $1.confidence }.prefix(topRawPerFrame))
        window.append(trimmed)
        if window.count > windowSize { window.removeFirst(window.count - windowSize) }
        return stableDetections()
    }

    func stableDetections() -> [Stable] {
        guard !window.isEmpty else { return [] }
        var bucket: [String: (count: Int, sumConfidence: Float, lastBox: CGRect)] = [:]
        for frame in window {
            for detection in frame {
                let key = normalizeKey(detection.label)
                let entry = bucket[key]
                let nextCount = (entry?.count ?? 0) + 1
                let nextSum = (entry?.sumConfidence ?? 0) + detection.confidence
                bucket[key] = (nextCount, nextSum, detection.boundingBox)
            }
        }
        return bucket.compactMap { key, value -> Stable? in
            guard value.count >= minOccurrences else { return nil }
            let mean = value.sumConfidence / Float(value.count)
            let ratio = Float(value.count) / Float(window.count)
            return Stable(
                label: key,
                smoothedConfidence: mean * ratio,
                lastBoundingBox: value.lastBox,
                occurrences: value.count
            )
        }
        .sorted { $0.smoothedConfidence > $1.smoothedConfidence }
    }

    func reset() { window.removeAll() }

    private func normalizeKey(_ label: String) -> String {
        label.lowercased(with: Locale(identifier: "en_US")).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Helper to convert stable detections back to CameraDetections

extension FoodDetectionStabilizer.Stable {
    var asCameraDetection: CameraDetection {
        CameraDetection(
            label: label,
            confidence: smoothedConfidence,
            boundingBox: lastBoundingBox
        )
    }
}
