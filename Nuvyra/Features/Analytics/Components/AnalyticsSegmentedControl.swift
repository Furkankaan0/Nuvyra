import SwiftUI

struct AnalyticsSegmentedControl: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        selection = period
                    }
                } label: {
                    Text(period.title)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selection == period ? .white : NuvyraColors.primaryText(scheme))
                        .background {
                            if selection == period {
                                Capsule()
                                    .fill(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(period.title)
                .accessibilityValue(selection == period ? "Seçili" : "Seçili değil")
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.34)))
    }
}
