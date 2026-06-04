import SwiftUI

/// Period picker for the Analytics screen. Wraps the brand-side
/// `NuvyraSegmentedPicker` so this file stays as the single place we'd
/// patch if the Analytics period list ever grew a new entry.
struct AnalyticsSegmentedControl: View {
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        NuvyraSegmentedPicker(
            selection: $selection,
            options: AnalyticsPeriod.allCases
        ) { period in
            Text(period.title)
        } accessibilityLabel: { period in
            period.title
        }
    }
}
