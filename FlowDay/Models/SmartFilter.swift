// SmartFilter.swift
// FlowDay
//
// Preset "smart views" that match Todoist's built-in filters
// (Today, Upcoming, Priority 1, etc.). Not stored in SwiftData —
// these are compiled into the app and applied on top of live task fetches.

import SwiftUI

enum SmartFilter: String, CaseIterable, Identifiable {
    case today
    case overdue
    case thisWeek
    case noDate
    case priority1
    case priority2Plus
    case scheduled
    case completedToday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:          "Today"
        case .overdue:        "Overdue"
        case .thisWeek:       "This Week"
        case .noDate:         "No Date"
        case .priority1:      "Urgent"
        case .priority2Plus:  "High Priority"
        case .scheduled:      "Scheduled"
        case .completedToday: "Completed Today"
        }
    }

    var iconName: String {
        switch self {
        case .today:          "sun.max"
        case .overdue:        "exclamationmark.triangle"
        case .thisWeek:       "calendar"
        case .noDate:         "tray"
        case .priority1:      "flag.fill"
        case .priority2Plus:  "flag"
        case .scheduled:      "clock"
        case .completedToday: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .today:          .fdAccent
        case .overdue:        .fdRed
        case .thisWeek:       .fdBlue
        case .noDate:         .fdTextSecondary
        case .priority1:      .fdRed
        case .priority2Plus:  .fdYellow
        case .scheduled:      .fdPurple
        case .completedToday: .fdGreen
        }
    }

    var emptyMessage: String {
        switch self {
        case .today:          "Nothing due or scheduled for today. Enjoy the calm."
        case .overdue:        "You're all caught up — no overdue tasks."
        case .thisWeek:       "No tasks this week yet. Add one from Today."
        case .noDate:         "No loose tasks. Everything is scheduled."
        case .priority1:      "No urgent tasks right now."
        case .priority2Plus:  "No high-priority tasks right now."
        case .scheduled:      "No scheduled tasks. Add a start time from a task's detail view."
        case .completedToday: "No tasks completed yet today. Pick one to start."
        }
    }

    /// Evaluate this filter against a task. The `now` parameter is injected
    /// so tests and previews can pin a specific date.
    func matches(_ task: FDTask, now: Date = .now, calendar: Calendar = .current) -> Bool {
        // Excluded from every filter except completedToday
        if case .completedToday = self {
            guard let completed = task.completedAt, !task.isDeleted else { return false }
            return calendar.isDate(completed, inSameDayAs: now)
        }

        guard !task.isDeleted, !task.isCompleted else { return false }

        switch self {
        case .today:
            if let scheduled = task.scheduledTime, calendar.isDate(scheduled, inSameDayAs: now) { return true }
            if let due = task.dueDate, calendar.isDate(due, inSameDayAs: now) { return true }
            return false

        case .overdue:
            guard let due = task.dueDate else { return false }
            return due < calendar.startOfDay(for: now)

        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            if let scheduled = task.scheduledTime, scheduled >= startOfWeek, scheduled < endOfWeek { return true }
            if let due = task.dueDate, due >= startOfWeek, due < endOfWeek { return true }
            return false

        case .noDate:
            return task.dueDate == nil && task.scheduledTime == nil && task.startDate == nil

        case .priority1:
            return task.priority == .urgent

        case .priority2Plus:
            return task.priority == .urgent || task.priority == .high

        case .scheduled:
            return task.scheduledTime != nil || task.startDate != nil

        case .completedToday:
            return false  // handled above
        }
    }

    /// Default sort order for matching tasks.
    func sortKey(for task: FDTask) -> Date {
        switch self {
        case .overdue, .thisWeek, .today:
            return task.scheduledTime ?? task.dueDate ?? .distantFuture
        case .priority1, .priority2Plus:
            return task.dueDate ?? .distantFuture
        case .noDate:
            return task.createdAt
        case .scheduled:
            return task.scheduledTime ?? task.startDate ?? .distantFuture
        case .completedToday:
            return task.completedAt ?? .distantPast
        }
    }
}
