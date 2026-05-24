import SwiftUI

struct DashboardGreetingHeader: View {
    var name: String
    var date: Date

    private var greeting: String {
        let hour = Calendar.nuvyra.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Günaydın"
        case 11..<17: return "Merhaba"
        case 17..<22: return "İyi akşamlar"
        default: return "İyi geceler"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("\(greeting), \(name)")
                .font(NuvyraTypography.hero)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(DateFormatter.nuvyraShortDate.string(from: date).capitalized)
                .font(NuvyraTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        DashboardGreetingHeader(name: "Furkan", date: Date()).padding()
    }
}
#endif
