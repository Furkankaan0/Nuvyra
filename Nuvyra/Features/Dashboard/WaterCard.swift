import SwiftUI

struct WaterCard: View {
    var waterMl: Int
    var targetMl: Int
    var onAdd250: () -> Void
    var onAdd500: () -> Void

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Su")
                            .font(NuvyraTypography.section)
                        Text("\(waterMl) ml")
                            .font(NuvyraTypography.metric)
                    }
                    Spacer()
                    NuvyraProgressRing(progress: Double(waterMl) / Double(max(targetMl, 1)), lineWidth: 9, center: "\(Int(min(Double(waterMl) / Double(max(targetMl, 1)), 1) * 100))%", caption: "su")
                        .frame(width: 92, height: 92)
                }
                HStack {
                    NuvyraSecondaryButton(title: "+250 ml", systemImage: "drop") { onAdd250() }
                    NuvyraSecondaryButton(title: "+500 ml", systemImage: "drop.fill") { onAdd500() }
                }
            }
        }
    }
}
