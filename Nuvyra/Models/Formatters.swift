import Foundation

extension Calendar {
    static var nuvyra: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        return calendar
    }

    func startAndEndOfDay(for date: Date) -> (Date, Date) {
        let start = startOfDay(for: date)
        let end = self.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }
}

extension DateFormatter {
    static let nuvyraShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let nuvyraWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "E"
        return formatter
    }()
}

extension Double {
    var cleanFormatted: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = self.rounded() == self ? 0 : 1
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
