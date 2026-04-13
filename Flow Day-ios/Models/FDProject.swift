// FDProject.swift
// FlowDay — Projects are UNLIMITED on free tier (Todoist limits to 5)

import Foundation
import SwiftData

@Model
final class FDProject {

    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String?
    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool
    var isFavorite: Bool
    var sections: [String]

    @Relationship(deleteRule: .nullify)
    var tasks: [FDTask]

    init(name: String, colorHex: String = "#D4713B", iconName: String? = nil, sections: [String] = []) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = 0
        self.createdAt = .now
        self.isArchived = false
        self.isFavorite = false
        self.sections = sections
        self.tasks = []
    }

    var activeTasks: [FDTask] { tasks.filter { !$0.isDeleted && !$0.isCompleted } }
    var completedTasks: [FDTask] { tasks.filter { $0.isCompleted && !$0.isDeleted } }

    var completionRate: Double {
        let total = tasks.filter { !$0.isDeleted }.count
        guard total > 0 else { return 0 }
        return Double(completedTasks.count) / Double(total)
    }

    static let templates: [(name: String, color: String, icon: String, sections: [String])] = [
        ("Work",         "#D4713B", "briefcase",  ["Backlog", "In Progress", "Done"]),
        ("Personal",     "#5B8FD4", "person",     []),
        ("Life",         "#5BA065", "leaf",       ["Errands", "Health", "Finance"]),
        ("Side Project", "#8B6BBF", "hammer",     ["Ideas", "Building", "Shipped"]),
        ("Learning",     "#D4A73B", "book",       ["Courses", "Books", "Practice"]),
    ]
}
