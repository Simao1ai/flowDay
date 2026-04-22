// FDTask.swift
// FlowDay
//
// Core task model — fixes every Todoist pain point:
// - Start dates AND due dates (Todoist only has due dates)
// - Duration estimates built in (Todoist paywalls this)
// - Inline subtasks via relationship (Todoist requires multi-step flow)
// - Soft-delete with undo (Todoist has no undo for project deletion)

import Foundation
import SwiftData
import SwiftUI

@Model
final class FDTask {

    var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var modifiedAt: Date

    // Scheduling — Todoist's biggest gap
    var startDate: Date?
    var dueDate: Date?
    var scheduledTime: Date?
    var estimatedMinutes: Int?

    // Organization
    var priority: TaskPriority
    var labels: [String]
    var sortOrder: Int
    /// Name of the section within the task's project. nil = "No Section".
    /// Matches a string in FDProject.sections. Kept as free-form text so renaming
    /// a section updates in one place without a separate join table.
    var section: String?

    // Status
    var isCompleted: Bool
    var completedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?

    // Recurrence
    var recurrenceRule: String?

    // AI metadata
    var aiSuggestedTime: Date?
    var cognitiveLoad: Int?

    // Attachments — stored as JSON-encoded [TaskAttachment]
    @Attribute(.externalStorage)
    var attachmentsData: Data

    // Relationships
    @Relationship(deleteRule: .cascade)
    var subtasks: [FDSubtask]

    @Relationship(inverse: \FDProject.tasks)
    var project: FDProject?

    init(
        title: String,
        notes: String = "",
        startDate: Date? = nil,
        dueDate: Date? = nil,
        scheduledTime: Date? = nil,
        estimatedMinutes: Int? = nil,
        priority: TaskPriority = .none,
        labels: [String] = [],
        section: String? = nil,
        recurrenceRule: String? = nil,
        cognitiveLoad: Int? = nil,
        project: FDProject? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.createdAt = .now
        self.modifiedAt = .now
        self.startDate = startDate
        self.dueDate = dueDate
        self.scheduledTime = scheduledTime
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
        self.labels = labels
        self.sortOrder = 0
        self.section = section
        self.isCompleted = false
        self.completedAt = nil
        self.isDeleted = false
        self.deletedAt = nil
        self.recurrenceRule = recurrenceRule
        self.aiSuggestedTime = nil
        self.cognitiveLoad = cognitiveLoad
        self.subtasks = []
        self.project = project
        self.attachmentsData = Data()
    }
}

// MARK: - Task Priority

enum TaskPriority: Int, Codable, CaseIterable, Comparable {
    case urgent = 1
    case high = 2
    case medium = 3
    case none = 4

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .urgent: "P1"
        case .high:   "P2"
        case .medium: "P3"
        case .none:   "P4"
        }
    }

    var colorName: String {
        switch self {
        case .urgent: "fdRed"
        case .high:   "fdYellow"
        case .medium: "fdBlue"
        case .none:   "fdGray"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return .fdRed
        case .high:   return .fdYellow
        case .medium: return .fdBlue
        case .none:   return .fdTextMuted
        }
    }
}

// MARK: - Convenience

extension FDTask {

    var activeSubtasks: [FDSubtask] {
        subtasks.filter { !$0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        return Double(subtasks.filter(\.isCompleted).count) / Double(subtasks.count)
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < .now
    }

    var isScheduledToday: Bool {
        if let time = scheduledTime { return Calendar.current.isDateInToday(time) }
        if let due = dueDate { return Calendar.current.isDateInToday(due) }
        return false
    }

    func complete() {
        isCompleted = true
        completedAt = .now
        modifiedAt = .now
    }

    func uncomplete() {
        isCompleted = false
        completedAt = nil
        modifiedAt = .now
    }

    func softDelete() {
        isDeleted = true
        deletedAt = .now
        modifiedAt = .now
    }

    func restore() {
        isDeleted = false
        deletedAt = nil
        modifiedAt = .now
    }
}

// MARK: - Attachments

extension FDTask {
    var attachments: [TaskAttachment] {
        get { (try? JSONDecoder().decode([TaskAttachment].self, from: attachmentsData)) ?? [] }
        set { attachmentsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func addAttachment(_ attachment: TaskAttachment) {
        var current = attachments
        current.append(attachment)
        attachments = current
        modifiedAt = .now
    }

    func removeAttachment(id: UUID) {
        var current = attachments
        if let idx = current.firstIndex(where: { $0.id == id }) {
            current[idx].deleteFile()
            current.remove(at: idx)
        }
        attachments = current
        modifiedAt = .now
    }
}
