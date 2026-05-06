import CoreHaptics
import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    func playMealAddedSuccess() {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: eventParameters(intensity: 0.42, sharpness: 0.28),
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: eventParameters(intensity: 0.74, sharpness: 0.48),
                relativeTime: 0.075
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: eventParameters(intensity: 0.24, sharpness: 0.18),
                relativeTime: 0.13,
                duration: 0.09
            )
        ]

        play(events: events, fallback: .light)
    }

    func playWalkingHalfwayRhythm() {
        let rhythmTimes: [TimeInterval] = [0, 0.11, 0.23, 0.39]
        let events = rhythmTimes.enumerated().map { index, time in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: eventParameters(
                    intensity: Float([0.45, 0.58, 0.72, 0.88][index]),
                    sharpness: Float([0.22, 0.28, 0.36, 0.44][index])
                ),
                relativeTime: time
            )
        } + [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: eventParameters(intensity: 0.18, sharpness: 0.16),
                relativeTime: 0.45,
                duration: 0.12
            )
        ]

        play(events: events, fallback: .medium)
    }

    func playWaterAdded() {
        playTransient(intensity: 0.34, sharpness: 0.22, fallback: .soft)
    }

    func playWalkStarted() {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.38, sharpness: 0.26), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.56, sharpness: 0.34), relativeTime: 0.14)
        ]
        play(events: events, fallback: .medium)
    }

    func playGoalCompleted() {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.52, sharpness: 0.34), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.88, sharpness: 0.54), relativeTime: 0.10),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.72, sharpness: 0.40), relativeTime: 0.26),
            CHHapticEvent(eventType: .hapticContinuous, parameters: eventParameters(intensity: 0.20, sharpness: 0.18), relativeTime: 0.32, duration: 0.10)
        ]
        play(events: events, fallback: .rigid)
    }

    func makeMealAddedSuccessPattern() throws -> CHHapticPattern {
        try CHHapticPattern(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.42, sharpness: 0.28), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.74, sharpness: 0.48), relativeTime: 0.075),
            CHHapticEvent(eventType: .hapticContinuous, parameters: eventParameters(intensity: 0.24, sharpness: 0.18), relativeTime: 0.13, duration: 0.09)
        ], parameters: [])
    }

    func makeWalkingHalfwayPattern() throws -> CHHapticPattern {
        try CHHapticPattern(events: [
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.45, sharpness: 0.22), relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.58, sharpness: 0.28), relativeTime: 0.11),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.72, sharpness: 0.36), relativeTime: 0.23),
            CHHapticEvent(eventType: .hapticTransient, parameters: eventParameters(intensity: 0.88, sharpness: 0.44), relativeTime: 0.39),
            CHHapticEvent(eventType: .hapticContinuous, parameters: eventParameters(intensity: 0.18, sharpness: 0.16), relativeTime: 0.45, duration: 0.12)
        ], parameters: [])
    }

    private func playTransient(
        intensity: Float,
        sharpness: Float,
        fallback: UIImpactFeedbackGenerator.FeedbackStyle
    ) {
        play(
            events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: eventParameters(intensity: intensity, sharpness: sharpness),
                    relativeTime: 0
                )
            ],
            fallback: fallback
        )
    }

    private func play(
        events: [CHHapticEvent],
        fallback: UIImpactFeedbackGenerator.FeedbackStyle
    ) {
        guard supportsHaptics, let engine else {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
            return
        }

        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
        }
    }

    private func eventParameters(
        intensity: Float,
        sharpness: Float
    ) -> [CHHapticEventParameter] {
        [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
    }
}
