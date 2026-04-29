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
