// FDHabit.swift
// FlowDay — Built-in habit tracking (Todoist doesn't have this)

import Foundation
import SwiftData

@Model
final class FDHabit {

    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date
    var frequency: HabitFrequency
    var preferredTime: HabitTimeSlot
    var currentStreak: Int
    var longestStreak: Int
    var isActive: Bool
    var sortOrder: Int

    @Relationship(deleteRule: .cascade)
    var logs: [FDHabitLog]

    init(
        name: String, emoji: String = "✓", colorHex: String = "#D4713B",
        frequency: HabitFrequency = .daily, preferredTime: HabitTimeSlot = .morning
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = .now
        self.frequency = frequency
        self.preferredTime = preferredTime
        self.currentStreak = 0
        self.longestStreak = 0
        self.isActive = true
        self.sortOrder = 0
        self.logs = []
    }
}

enum HabitFrequency: Codable {
    case daily, weekdays, weekends
    case specificDays([Int])
    case timesPerWeek(Int)

    var displayText: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .specificDays(let days):
            let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days.map { names[$0] }.joined(separator: ", ")
        case .timesPerWeek(let n): return "\(n)x per week"
        }
    }
}

enum HabitTimeSlot: String, Codable, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case anytime = "Anytime"
}

extension FDHabit {

    var isDueToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: .now)
        switch frequency {
        case .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .specificDays(let days): return days.contains(weekday)
        case .timesPerWeek: return true
        }
    }

    var isCompletedToday: Bool {
        logs.contains { Calendar.current.isDateInToday($0.date) }
    }

    @discardableResult
    func toggleToday() -> FDHabitLog? {
        if let existing = logs.first(where: { Calendar.current.isDateInToday($0.date) }) {
            logs.removeAll { $0.id == existing.id }
            recalculateStreak()
            return nil
        } else {
            let log = FDHabitLog(habit: self)
            logs.append(log)
            recalculateStreak()
            return log
        }
    }

    private func recalculateStreak() {
        let sortedDates = logs.map(\.date).sorted(by: >)
        guard let latest = sortedDates.first,
              Calendar.current.isDateInToday(latest) || Calendar.current.isDateInYesterday(latest)
        else { currentStreak = 0; return }

        var streak = 1
        var checkDate = Calendar.current.date(byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: latest))!

        for date in sortedDates.dropFirst() {
            let dayStart = Calendar.current.startOfDay(for: date)
            if dayStart == checkDate {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            } else if dayStart < checkDate { break }
        }
        currentStreak = streak
        if streak > longestStreak { longestStreak = streak }
    }
}
