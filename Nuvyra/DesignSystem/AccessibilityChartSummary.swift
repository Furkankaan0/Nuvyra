import SwiftUI

/// Reusable accessibility summary applied on top of a SwiftUI `Chart`. Charts
/// expose per-mark labels already, but VoiceOver users still benefit from a
/// single-line headline they can read before they decide to drill in.
///
/// Usage:
/// ```swift
/// Chart { ... }
///   .modifier(AccessibilityChartSummary(label: "Haftalık su", value: "Ort. 1.850 ml", hint: "Detay için listeye git"))
/// ```
struct AccessibilityChartSummary: ViewModifier {
    let label: String
    let value: String
    var hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint ?? "Detayı keşfetmek için aşağı kaydır")
    }
}

extension View {
    /// Convenience wrapper to give a chart a single VoiceOver headline + value.
    func nuvyraChartSummary(label: String, value: String, hint: String? = nil) -> some View {
        modifier(AccessibilityChartSummary(label: label, value: value, hint: hint))
    }
}

/// Numeric helpers used while building chart accessibility text.
enum ChartAccessibilitySummary {
    /// Returns a compact "Ort. X · En yüksek Y · En düşük Z" string from a numeric series.
    static func summary(values: [Double], unit: String, formatter: ((Double) -> String)? = nil) -> String {
        guard !values.isEmpty else { return "Veri yok" }
        let fmt: (Double) -> String = formatter ?? { String(format: "%.0f", $0) }
        let avg = values.reduce(0, +) / Double(values.count)
        let max = values.max() ?? 0
        let min = values.min() ?? 0
        return "Ortalama \(fmt(avg)) \(unit). En yüksek \(fmt(max)). En düşük \(fmt(min))."
    }

    static func summary(intValues: [Int], unit: String) -> String {
        summary(values: intValues.map(Double.init), unit: unit)
    }
}
