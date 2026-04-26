// WidgetModels.swift
// Shared between FlowDay app and FlowDayWidgets extension
// Compiled into both targets via project.yml source paths

import Foundation

// MARK: - App Group

let kWidgetAppGroup = "group.io.flowday.app"

enum WidgetDataKeys {
    static let summary    = "fd.widget.summary"
    static let focusState = "fd.widget.focusState"
}

// MARK: - WidgetTask

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let priorityRaw: Int        // 1=urgent, 2=high, 3=medium, 4=none
    let scheduledTime: Date?
    let dueDate: Date?
    let projectName: String?
    let projectColorHex: String?
    let estimatedMinutes: Int?

    var displayTime: Date? { scheduledTime ?? dueDate }
}

extension WidgetTask {
    static let placeholder = WidgetTask(
        id: UUID(),
        title: "Design new feature",
        priorityRaw: 2,
        scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: .now),
        dueDate: nil,
        projectName: "Work",
        projectColorHex: "D4713B",
        estimatedMinutes: 30
    )
}

// MARK: - WidgetSummary

struct WidgetSummary: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let focusMinutesToday: Int
    let focusSessionsToday: Int
    let focusScore: Int
    let energyLevel: String?    // "high", "normal", "low"
    let upcomingTasks: [WidgetTask]
    let updatedAt: Date

    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    var nextTask: WidgetTask? { upcomingTasks.first }

    static func load() -> WidgetSummary? {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroup),
              let data = defaults.data(forKey: WidgetDataKeys.summary) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }
}

extension WidgetSummary {
    static let placeholder = WidgetSummary(
        totalTasks: 6,
        completedTasks: 2,
        focusMinutesToday: 50,
        focusSessionsToday: 2,
        focusScore: 72,
        energyLevel: "high",
        upcomingTasks: [.placeholder],
        updatedAt: .now
    )
}

// MARK: - WidgetFocusState

struct WidgetFocusState: Codable {
    let sessionType: String     // "Focus", "Short Break", "Long Break"
    let startedAt: Date
    let durationMinutes: Int
    let taskTitle: String?

    var endTime: Date { startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
    var isBreak: Bool { sessionType != "Focus" }

    static func load() -> WidgetFocusState? {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroup),
              let data = defaults.data(forKey: WidgetDataKeys.focusState) else { return nil }
        return try? JSONDecoder().decode(WidgetFocusState.self, from: data)
    }
}
