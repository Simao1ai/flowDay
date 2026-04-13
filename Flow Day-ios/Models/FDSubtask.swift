// FDSubtask.swift
// FlowDay

import Foundation
import SwiftData

@Model
final class FDSubtask {

    var id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date
    var estimatedMinutes: Int?

    @Relationship(inverse: \FDTask.subtasks)
    var parentTask: FDTask?

    init(title: String, sortOrder: Int = 0, estimatedMinutes: Int? = nil, parentTask: FDTask? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.estimatedMinutes = estimatedMinutes
        self.parentTask = parentTask
    }

    func complete() { isCompleted = true; completedAt = .now }
    func uncomplete() { isCompleted = false; completedAt = nil }
}
