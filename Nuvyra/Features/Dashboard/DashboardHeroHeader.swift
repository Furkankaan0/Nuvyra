import SwiftUI

struct DashboardHeroHeader: View {
    @Environment(\.colorScheme) private var scheme
    var userName: String?
    var date: Date
    var insight: String
    var onTapInsight: () -> Void = {}

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    private var greeting: String {
        let hour = Calendar.nuvyra.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<17: return "İyi günler"
        case 17..<22: return "İyi akşamlar"
        default: return "İyi geceler"
        }
    }

    private var displayName: String? {
        userName?.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.dateFormatter.string(from: date))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(NuvyraColors.accent)
                    .textCase(.uppercase)

                Text(displayName.map { "\(greeting), \($0)." } ?? "\(greeting).")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Button(action: onTapInsight) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [NuvyraColors.accent, NuvyraColors.softMint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                    Text(insight)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent.opacity(0.6))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                        .stroke(NuvyraColors.accent.opacity(0.14))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AI Coach içgörüsü: \(insight). Detay için dokun.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        DashboardHeroHeader(
            userName: "Furkan",
            date: Date(),
            insight: "Bugün adım hedefin yarısında. Akşam kısa bir yürüyüş ritmini tamamlar."
        )
        DashboardHeroHeader(
            userName: nil,
            date: Date(),
            insight: "İlk öğününü ekleyerek günün dengesini görmeye başla."
        )
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
