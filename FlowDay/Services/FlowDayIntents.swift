// FlowDayIntents.swift
// FlowDay
//
// App Intents expose task actions to Siri, Shortcuts, Spotlight, and the
// Action Button on supported devices. Each intent spins up its own
// ModelContainer so it can run independent of the main app process.

import Foundation
import AppIntents
import SwiftData
import SwiftUI

// MARK: - Shared ModelContainer factory

@MainActor
enum FlowDayIntentsRuntime {
    /// Recreates the schema used by the main app. Kept identical to
    /// FlowDayApp.sharedModelContainer so intents operate on the same store.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FDTask.self,
            FDSubtask.self,
            FDProject.self,
            FDHabit.self,
            FDHabitLog.self,
            FDEnergyLog.self,
            FDFocusSession.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - Add Task

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription(
        "Quickly capture a task in FlowDay. Supports natural language for dates and priority."
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var title: String

    @Parameter(title: "Priority", default: .none)
    var priority: TaskPriorityAppEnum

    @Parameter(title: "Due Date")
    var dueDate: Date?

    @Parameter(title: "Estimated Minutes")
    var estimatedMinutes: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title)") {
            \.$priority
            \.$dueDate
            \.$estimatedMinutes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try FlowDayIntentsRuntime.makeContainer()
        let context = ModelContext(container)

        let task = FDTask(
            title: title,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            priority: priority.toDomain
        )
        context.insert(task)
        try context.save()

        Task { await SupabaseService.shared.syncTask(task) }

        return .result(dialog: "Added \"\(title)\" to FlowDay.")
    }
}

// MARK: - Complete Task

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription(
        "Mark a FlowDay task as done by name. Matches on a fuzzy title lookup."
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task Name")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try FlowDayIntentsRuntime.makeContainer()
        let context = ModelContext(container)

        let all = try context.fetch(FetchDescriptor<FDTask>())
        let needle = query.lowercased()
        guard let match = all.first(where: {
            !$0.isDeleted && !$0.isCompleted && $0.title.lowercased().contains(needle)
        }) else {
            return .result(dialog: "No active task matched \"\(query)\".")
        }

        match.complete()
        try context.save()

        Task { await SupabaseService.shared.syncTask(match) }

        return .result(dialog: "Marked \"\(match.title)\" as complete.")
    }
}

// MARK: - Plan My Day

struct PlanDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Plan My Day"
    static var description = IntentDescription(
        "Open FlowDay and jump straight to Flow AI to plan today around your energy."
    )

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Main app handles the navigation via .handlesExternalEvents — here
        // we just signal intent-run so openAppWhenRun opens FlowDay.
        return .result()
    }
}

// MARK: - Task Count (a simple stats intent)

struct TaskCountIntent: AppIntent {
    static var title: LocalizedStringResource = "How Many Tasks Left"
    static var description = IntentDescription(
        "Reports the number of active tasks remaining for today."
    )

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let container = try FlowDayIntentsRuntime.makeContainer()
        let context = ModelContext(container)

        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            return .result(value: 0, dialog: "Couldn't read your schedule.")
        }

        let all = try context.fetch(FetchDescriptor<FDTask>())
        let count = all.filter { task in
            !task.isDeleted && !task.isCompleted &&
            (
                (task.scheduledTime.map { $0 >= start && $0 < end } ?? false) ||
                (task.dueDate.map { $0 >= start && $0 < end } ?? false)
            )
        }.count

        let message: String = count == 0
            ? "You're all done for today."
            : count == 1 ? "One task left for today."
            : "\(count) tasks left for today."

        return .result(value: count, dialog: IntentDialog(full: message, supporting: message))
    }
}

// MARK: - Parameter Enum for Priority

enum TaskPriorityAppEnum: String, AppEnum {
    case urgent
    case high
    case medium
    case none

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"
    static var caseDisplayRepresentations: [TaskPriorityAppEnum: DisplayRepresentation] = [
        .urgent: "P1 — Urgent",
        .high:   "P2 — High",
        .medium: "P3 — Medium",
        .none:   "P4 — None"
    ]

    var toDomain: TaskPriority {
        switch self {
        case .urgent: .urgent
        case .high:   .high
        case .medium: .medium
        case .none:   .none
        }
    }
}

// MARK: - Shortcut Provider (Siri suggestions)

struct FlowDayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "New \(.applicationName) task",
                "Capture a task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
                "Mark \(.applicationName) task as done",
                "Finish a task in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: PlanDayIntent(),
            phrases: [
                "Plan my day with \(.applicationName)",
                "Open \(.applicationName) planner"
            ],
            shortTitle: "Plan My Day",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: TaskCountIntent(),
            phrases: [
                "How many \(.applicationName) tasks do I have left",
                "What's left in \(.applicationName) today"
            ],
            shortTitle: "Tasks Remaining",
            systemImageName: "number"
        )
    }
}
