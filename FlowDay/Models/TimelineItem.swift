// TimelineItem.swift
// FlowDay — Unified type powering the Daily Timeline view

import Foundation
import EventKit

enum TimelineItem: Identifiable {
    case task(FDTask)
    case calendarEvent(EKEvent)
    case habit(FDHabit)

    var id: String {
        switch self {
        case .task(let t):          t.id.uuidString
        case .calendarEvent(let e): e.eventIdentifier ?? UUID().uuidString
        case .habit(let h):         "habit-\(h.id.uuidString)"
        }
    }

    var sortTime: Date {
        switch self {
        case .task(let t):
            return t.scheduledTime ?? t.dueDate ?? .distantFuture
        case .calendarEvent(let e):
            return e.startDate ?? .distantFuture
        case .habit(let h):
            let cal = Calendar.current; let now = Date.now
            switch h.preferredTime {
            case .morning:   return cal.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
            case .afternoon: return cal.date(bySettingHour: 13, minute: 0, second: 0, of: now) ?? now
            case .evening:   return cal.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
            case .anytime:   return cal.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
            }
        }
    }

    var durationMinutes: Int {
        switch self {
        case .task(let t): return t.estimatedMinutes ?? 30
        case .calendarEvent(let e):
            guard let s = e.startDate, let end = e.endDate else { return 30 }
            return Int(end.timeIntervalSince(s) / 60)
        case .habit: return 15
        }
    }

    var isCompleted: Bool {
        switch self {
        case .task(let t):   t.isCompleted
        case .calendarEvent: false
        case .habit(let h):  h.isCompletedToday
        }
    }
}

struct TimelineBuilder {
    static func buildTimeline(tasks: [FDTask], events: [EKEvent], habits: [FDHabit], for date: Date) -> [TimelineItem] {
        let cal = Calendar.current
        let dayTasks = tasks.filter { t in
            guard !t.isDeleted else { return false }
            if let time = t.scheduledTime { return cal.isDate(time, inSameDayAs: date) }
            if let due = t.dueDate { return cal.isDate(due, inSameDayAs: date) }
            return false
        }
        let dayHabits = habits.filter { $0.isActive && $0.isDueToday }
        var items: [TimelineItem] = []
        items += dayTasks.map { .task($0) }
        items += events.map { .calendarEvent($0) }
        items += dayHabits.map { .habit($0) }
        items.sort { $0.sortTime < $1.sortTime }
        return items
    }

    static func unscheduledTasks(from tasks: [FDTask]) -> [FDTask] {
        tasks.filter { !$0.isDeleted && !$0.isCompleted && $0.scheduledTime == nil && $0.dueDate == nil }
            .sorted { $0.priority < $1.priority }
    }
}
