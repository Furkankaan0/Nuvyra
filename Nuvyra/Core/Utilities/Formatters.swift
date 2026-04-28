import Foundation

extension Double {
    var roundedInt: Int { Int(self.rounded()) }
}

extension DateFormatter {
    static let nuvyraDayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let nuvyraShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let nuvyraTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

extension Calendar {
    func isDateInCurrentWeek(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}
