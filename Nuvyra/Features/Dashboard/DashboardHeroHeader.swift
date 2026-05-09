import SwiftUI

struct DashboardHeroHeader: View {
    @Environment(\.colorScheme) private var scheme
    var userName: String?
    var date: Date

    private var greeting: String {
        let hour = Calendar.nuvyra.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<17: return "İyi günler"
        case 17..<22: return "İyi akşamlar"
        default: return "İyi geceler"
        }
    }

    private var displayName: String {
        let trimmed = userName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "" }
        return trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateFormatter.nuvyraShortDate.string(from: date))
                .font(NuvyraTypography.caption)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            Text(displayName.isEmpty ? "\(greeting)," : "\(greeting), \(displayName)")
                .font(NuvyraTypography.hero)
                .foregroundStyle(NuvyraColors.primaryText(scheme))
            Text("Bugünkü ritmin tek bakışta.")
                .font(NuvyraTypography.body)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    VStack {
        DashboardHeroHeader(userName: "Furkan", date: Date())
        DashboardHeroHeader(userName: nil, date: Date())
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
