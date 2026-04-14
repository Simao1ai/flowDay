// FDHabitLog.swift
// FlowDay

import Foundation
import SwiftData

@Model
final class FDHabitLog {
    var id: UUID
    var date: Date
    var note: String?

    @Relationship(inverse: \FDHabit.logs)
    var habit: FDHabit?

    init(habit: FDHabit? = nil, date: Date = .now, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.habit = habit
    }
}
