// TaskService.swift
// FlowDay
//
// The service layer for all task operations. Views talk to this,
// not directly to SwiftData. This keeps the views thin and makes
// testing + undo trivial.
//
// Supabase sync: every mutating operation fires an async sync to Supabase
// after the local SwiftData save. Local-first — the sync never blocks the UI.

import Foundation
import SwiftData
import SwiftUI

@Observable
final class TaskService {

    private let modelContext: ModelContext

    // MARK: - Undo Stack (fixes Todoist's #7 pain point)

    private var undoStack: [UndoAction] = []
    private let maxUndoDepth = 50

    enum UndoAction {
        case deletedTask(FDTask)
        case completedTask(FDTask)
        case deletedSubtask(FDSubtask, parentTask: FDTask)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// Create a new task with optional natural language parsing
    @discardableResult
    func createTask(
        title: String,
        notes: String = "",
        project: FDProject? = nil,
        priority: TaskPriority = .none,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        scheduledTime: Date? = nil,
        estimatedMinutes: Int? = nil,
        labels: [String] = [],
        section: String? = nil,
        recurrenceRule: String? = nil
    ) -> FDTask {
        let task = FDTask(
            title: title,
            notes: notes,
            startDate: startDate,
            dueDate: dueDate,
            scheduledTime: scheduledTime,
            estimatedMinutes: estimatedMinutes,
            priority: priority,
            labels: labels,
            section: section,
            recurrenceRule: recurrenceRule,
            project: project
        )
        modelContext.insert(task)
        save()
        Task { await SupabaseService.shared.syncTask(task) }
        return task
    }

    // MARK: - Sections

    /// Move a task into a named section (or clear the section with nil).
    func moveTask(_ task: FDTask, to section: String?) {
        task.section = section
        task.modifiedAt = .now
        save()
        Task { await SupabaseService.shared.syncTask(task) }
    }

    /// Add a section to a project. Idempotent.
    func addSection(_ name: String, to project: FDProject) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !project.sections.contains(trimmed) else { return }
        project.sections.append(trimmed)
        save()
        Task { await SupabaseService.shared.syncProject(project) }
    }

    /// Rename a section and all tasks that reference it.
    func renameSection(_ oldName: String, to newName: String, in project: FDProject) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, oldName != trimmed else { return }
        project.sections = project.sections.map { $0 == oldName ? trimmed : $0 }
        for task in project.tasks where task.section == oldName {
            task.section = trimmed
            task.modifiedAt = .now
        }
        save()
        Task {
            await SupabaseService.shared.syncProject(project)
            for task in project.tasks where task.section == trimmed {
                await SupabaseService.shared.syncTask(task)
            }
        }
    }

    /// Delete a section. Tasks in it are moved to "no section", not deleted.
    func deleteSection(_ name: String, in project: FDProject) {
        project.sections.removeAll { $0 == name }
        for task in project.tasks where task.section == name {
            task.section = nil
            task.modifiedAt = .now
        }
        save()
        Task {
            await SupabaseService.shared.syncProject(project)
            for task in project.tasks where task.section == nil {
                await SupabaseService.shared.syncTask(task)
            }
        }
    }

    /// Add a subtask inline (no navigation required — fixes Todoist UX)
    @discardableResult
    func addSubtask(to task: FDTask, title: String, estimatedMinutes: Int? = nil) -> FDSubtask {
        let subtask = FDSubtask(
            title: title,
            sortOrder: task.subtasks.count,
            estimatedMinutes: estimatedMinutes,
            parentTask: task
        )
        task.subtasks.append(subtask)
        task.modifiedAt = .now
        save()
        return subtask
    }

    // MARK: - Complete

    func toggleComplete(_ task: FDTask, energyLevel: EnergyLevel? = nil) {
        if task.isCompleted {
            task.uncomplete()
            save()
            Task { await SupabaseService.shared.syncTask(task) }
        } else {
            task.complete()
            pushUndo(.completedTask(task))
            save()
            Task {
                await SupabaseService.shared.syncTask(task)
                await SupabaseService.shared.recordCompletion(task: task, energyLevel: energyLevel)
                await MainActor.run {
                    GamificationService.shared.record(.taskCompleted(priority: task.priority.rawValue))
                }
            }
            // If recurring, create the next occurrence
            if task.recurrenceRule != nil {
                createNextOccurrence(for: task)
            }
        }
    }

    func toggleSubtaskComplete(_ subtask: FDSubtask) {
        if subtask.isCompleted {
            subtask.uncomplete()
        } else {
            subtask.complete()
        }
        subtask.parentTask?.modifiedAt = .now
        save()
    }

    // MARK: - Delete (soft delete with undo)

    func deleteTask(_ task: FDTask) {
        task.softDelete()
        pushUndo(.deletedTask(task))
        save()
        Task { await SupabaseService.shared.syncTask(task) }
    }

    func restoreTask(_ task: FDTask) {
        task.restore()
        save()
        Task { await SupabaseService.shared.syncTask(task) }
    }

    // MARK: - Update

    func updateTask(_ task: FDTask, title: String? = nil, notes: String? = nil,
                    dueDate: Date? = nil, startDate: Date? = nil,
                    scheduledTime: Date? = nil, estimatedMinutes: Int? = nil,
                    priority: TaskPriority? = nil, project: FDProject? = nil) {
        if let title { task.title = title }
        if let notes { task.notes = notes }
        if let dueDate { task.dueDate = dueDate }
        if let startDate { task.startDate = startDate }
        if let scheduledTime { task.scheduledTime = scheduledTime }
        if let estimatedMinutes { task.estimatedMinutes = estimatedMinutes }
        if let priority { task.priority = priority }
        if let project { task.project = project }
        task.modifiedAt = .now
        save()
        Task { await SupabaseService.shared.syncTask(task) }
    }

    func rescheduleTask(_ task: FDTask, to time: Date) {
        task.scheduledTime = time
        task.modifiedAt = .now
        save()
        Task { await SupabaseService.shared.syncTask(task) }
    }

    // MARK: - Queries

    // All fetches use plain FetchDescriptor — predicates/sorts crash on iOS 26.x
    func tasksForToday() -> [FDTask] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let all = (try? modelContext.fetch(FetchDescriptor<FDTask>())) ?? []
        return all.filter { task in
            !task.isDeleted &&
            (
                (task.scheduledTime != nil && task.scheduledTime! >= startOfDay && task.scheduledTime! < endOfDay) ||
                (task.dueDate != nil && task.dueDate! >= startOfDay && task.dueDate! < endOfDay)
            )
        }
        .sorted { ($0.scheduledTime ?? .distantFuture) < ($1.scheduledTime ?? .distantFuture) }
    }

    func overdueTasks() -> [FDTask] {
        let now = Date.now
        let all = (try? modelContext.fetch(FetchDescriptor<FDTask>())) ?? []
        return all.filter { !$0.isDeleted && !$0.isCompleted && $0.dueDate != nil && $0.dueDate! < now }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func inboxTasks() -> [FDTask] {
        let all = (try? modelContext.fetch(FetchDescriptor<FDTask>())) ?? []
        return all.filter { !$0.isDeleted && !$0.isCompleted && $0.scheduledTime == nil && $0.dueDate == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Undo

    func undo() -> Bool {
        guard let action = undoStack.popLast() else { return false }
        switch action {
        case .deletedTask(let task):
            task.restore()
        case .completedTask(let task):
            task.uncomplete()
        case .deletedSubtask(let subtask, let parent):
            parent.subtasks.append(subtask)
        }
        save()
        return true
    }

    var canUndo: Bool { !undoStack.isEmpty }

    // MARK: - Private

    private func pushUndo(_ action: UndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst()
        }
    }

    private func save() {
        try? modelContext.save()
    }

    /// Creates the next occurrence of a recurring task
    private func createNextOccurrence(for task: FDTask) {
        // Simplified: add 1 day for daily tasks, 7 for weekly
        // Full implementation would parse RRULE format
        guard let rule = task.recurrenceRule else { return }

        var nextDate: Date?
        if rule.contains("DAILY") {
            nextDate = Calendar.current.date(byAdding: .day, value: 1, to: task.dueDate ?? .now)
        } else if rule.contains("WEEKLY") {
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: task.dueDate ?? .now)
        }

        if let nextDate {
            let next = FDTask(
                title: task.title,
                notes: task.notes,
                dueDate: nextDate,
                priority: task.priority,
                labels: task.labels,
                section: task.section,
                recurrenceRule: task.recurrenceRule,
                cognitiveLoad: task.cognitiveLoad,
                project: task.project
            )
            modelContext.insert(next)
        }
    }
}
