import SwiftUI

struct NuvyraDateNavigator: View {
    @Binding var date: Date
    var title: String = "Tarih"
    var allowsFutureDates = false

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Button {
                moveDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Önceki gün")

            DatePicker(title, selection: $date, in: dateRange, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())

            Button {
                moveDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!allowsFutureDates && Calendar.nuvyra.isDateInToday(date))
            .accessibilityLabel("Sonraki gün")
        }
    }

    private var dateRange: PartialRangeThrough<Date> {
        ...Date()
    }

    private func moveDay(_ value: Int) {
        let next = Calendar.nuvyra.date(byAdding: .day, value: value, to: date) ?? date
        if allowsFutureDates || next <= Date() {
            date = next
        }
    }
}
