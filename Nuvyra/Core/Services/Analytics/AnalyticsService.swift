import Foundation

protocol AnalyticsServicing {
    func track(_ event: AnalyticsEvent) async
}

actor AnalyticsService: AnalyticsServicing {
    private var bufferedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) async {
        // MVP privacy-first: keep events local/in-memory until a vetted analytics backend exists.
        bufferedEvents.append(event)
    }

    func drainForDebug() -> [AnalyticsEvent] {
        bufferedEvents
    }
}

struct NoopAnalyticsService: AnalyticsServicing {
    func track(_ event: AnalyticsEvent) async {}
}
