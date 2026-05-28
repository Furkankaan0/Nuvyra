import SwiftUI

/// Per-100g mikronutrient paneli. Sadece dolu (nil olmayan) alanları gösterir
/// — eksik veri için boşluk bırakmaktansa o satırı tamamen atlar.
/// Minerals önce, sonra vitaminler, sonra cholesterol şeklinde ordered.
struct MicronutrientsPanel: View {
    let micronutrients: Micronutrients

    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let unit: String
    }

    private var rows: [Row] {
        var out: [Row] = []
        let m = micronutrients

        func add(_ label: String, _ value: Double?, _ unit: String) {
            guard let value, value > 0 else { return }
            out.append(Row(label: label, value: value, unit: unit))
        }

        add("Kalsiyum", m.calciumMg, "mg")
        add("Demir", m.ironMg, "mg")
        add("Magnezyum", m.magnesiumMg, "mg")
        add("Fosfor", m.phosphorusMg, "mg")
        add("Potasyum", m.potassiumMg, "mg")
        add("Çinko", m.zincMg, "mg")
        add("Kolesterol", m.cholesterolMg, "mg")

        add("Vitamin A", m.vitaminAUg, "µg")
        add("Vitamin C", m.vitaminCMg, "mg")
        add("Vitamin D", m.vitaminDUg, "µg")
        add("Vitamin E", m.vitaminEMg, "mg")
        add("Vitamin K", m.vitaminKUg, "µg")
        add("B1 (Tiamin)", m.vitaminB1Mg, "mg")
        add("B2 (Riboflavin)", m.vitaminB2Mg, "mg")
        add("B3 (Niasin)", m.vitaminB3Mg, "mg")
        add("B6", m.vitaminB6Mg, "mg")
        add("Folat (B9)", m.folateUg, "µg")
        add("B12", m.vitaminB12Ug, "µg")

        return out
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Mikrobesinler — 100 g başına")
                    .font(NuvyraTypography.section)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 8) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(NuvyraColors.accent.opacity(0.18))
                                .frame(width: 6, height: 6)
                            Text(row.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text(formatted(row))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func formatted(_ row: Row) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = row.value < 1 ? 2 : 0
        formatter.maximumFractionDigits = row.value < 1 ? 2 : 1
        let number = formatter.string(from: NSNumber(value: row.value)) ?? "\(row.value)"
        return "\(number) \(row.unit)"
    }
}

#Preview {
    MicronutrientsPanel(micronutrients: Micronutrients(
        calciumMg: 120, ironMg: 2.4, magnesiumMg: 80, potassiumMg: 380,
        zincMg: 1.1, vitaminCMg: 14, vitaminB6Mg: 0.4, vitaminB12Ug: 0.8,
        cholesterolMg: 65
    ))
    .padding()
}
