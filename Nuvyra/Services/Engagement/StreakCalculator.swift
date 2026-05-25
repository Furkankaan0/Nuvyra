import Foundation

/// Generic streak rollup the UI can render. Built deliberately content-agnostic
/// so it covers water, meals, walking and any future habit (Caffeine-free days, etc).
struct StreakInsight: Equatable, Hashable {
    /// Current run of consecutive completed days ending today.
    /// 0 if today is incomplete and yesterday wasn't either.
    let currentStreak: Int
    /// Longest run found inside the lookback window.
    let longestStreak: Int
    /// Whether today's target was already hit.
    let todayCompleted: Bool
    /// Completion flags for the last 7 days, **oldest → newest**.
    /// Index 6 is "today", index 0 is "6 days ago".
    let lastSevenDays: [Bool]

    static let empty = StreakInsight(currentStreak: 0, longestStreak: 0, todayCompleted: false, lastSevenDays: Array(repeating: false, count: 7))
}

enum StreakCalculator {
    /// Walk `daysBack` days backward asking `isCompleted` for each. We tolerate
    /// today being incomplete *only* if at least one earlier day in the streak
    /// was — that way "I'll complete it later" doesn't immediately break the run.
    static func calculate(
        daysBack: Int = 60,
        endingOn endDate: Date = Date(),
        calendar: Calendar = .nuvyra,
        isCompleted: (Date) -> Bool
    ) -> StreakInsight {
        let startOfToday = calendar.startOfDay(for: endDate)
        let days: [Date] = (0..<daysBack).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: startOfToday)
        }
        // Map newest → oldest (index 0 = today)
        let completion = days.map(isCompleted)
        guard !completion.isEmpty else { return .empty }

        let todayCompleted = completion[0]

        // Current streak: walk newest→older. If today is incomplete we still
        // count the streak ending yesterday, because day isn't over yet.
        var current = 0
        let startIndex = todayCompleted ? 0 : 1
        for index in startIndex..<completion.count {
            if completion[index] { current += 1 } else { break }
        }

        // Longest streak inside the window — straightforward run scan.
        var longest = 0
        var running = 0
        for done in completion {
            if done { running += 1; longest = max(longest, running) }
            else { running = 0 }
        }

        // Last 7 days oldest → newest. completion[0] = today, so reverse the first 7.
        let lastSevenSlice = Array(completion.prefix(7)).reversed()
        let lastSeven = Array(lastSevenSlice)
        let padded: [Bool] = lastSeven.count == 7 ? lastSeven : Array(repeating: false, count: 7 - lastSeven.count) + lastSeven

        return StreakInsight(
            currentStreak: current,
            longestStreak: longest,
            todayCompleted: todayCompleted,
            lastSevenDays: padded
        )
    }
}
