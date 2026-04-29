import CoreHaptics
import UIKit

@MainActor
protocol HapticsService {
    func mealLogged()
    func waterAdded()
    func walkStarted()
    func goalCompleted()
}

@MainActor
final class LiveHapticsService: HapticsService {
    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    func mealLogged() {
        playTransient(intensity: 0.58, sharpness: 0.42, fallback: .light)
    }

    func waterAdded() {
        playTransient(intensity: 0.44, sharpness: 0.30, fallback: .soft)
    }

    func walkStarted() {
        playPattern(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: 0.45, sharpness: 0.35), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: 0.62, sharpness: 0.42), relativeTime: 0.14)
        ], fallback: .medium)
    }

    func goalCompleted() {
        playPattern(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: 0.52, sharpness: 0.38), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: 0.86, sharpness: 0.52), relativeTime: 0.12),
            CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: 0.70, sharpness: 0.40), relativeTime: 0.28)
        ], fallback: .rigid)
    }

    private func playTransient(intensity: Float, sharpness: Float, fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: parameters(intensity: intensity, sharpness: sharpness), relativeTime: 0)
        playPattern(events: [event], fallback: fallback)
    }

    private func playPattern(events: [CHHapticEvent], fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard let engine, let pattern = try? CHHapticPattern(events: events, parameters: []) else {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
            return
        }
        do {
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
        }
    }

    private func parameters(intensity: Float, sharpness: Float) -> [CHHapticEventParameter] {
        [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
    }
}

@MainActor
struct MockHapticsService: HapticsService {
    func mealLogged() {}
    func waterAdded() {}
    func walkStarted() {}
    func goalCompleted() {}
}
