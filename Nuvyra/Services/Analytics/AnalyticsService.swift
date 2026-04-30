import Foundation

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent, payload: AnalyticsPayload) async
}

actor MockAnalyticsService: AnalyticsService {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent, payload: AnalyticsPayload = AnalyticsPayload()) async {
        events.append(event)
    }
}

actor PrivacyPreservingAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent, payload: AnalyticsPayload = AnalyticsPayload()) async {
        // Intentionally no-op until a privacy-reviewed analytics provider is selected.
        // Health, meal, weight, or exact activity data must not be sent to ad/marketing SDKs.
    }
}
