// PremiumTemplate.swift
// FlowDay
//
// Rich template data model for flagship templates.
// Plain Codable struct — NOT a SwiftData @Model.
// Applied to the user's modelContext via TemplatesView+Apply.applyPremiumTemplate().

import Foundation

struct PremiumTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let colorHex: String
    let category: String
    /// Shown in the template detail view before the user applies it.
    let howToUse: String
    let sections: [TemplateSection]

    struct TemplateSection: Codable, Identifiable {
        let id: String
        let title: String
        let emoji: String
        let description: String
        let tasks: [TemplateTask]
    }

    struct TemplateTask: Codable, Identifiable {
        let id: String
        let title: String
        /// Shown in the task notes field after the template is applied.
        let notes: String?
        /// Days from the date the template is applied. nil = no due date.
        let relativeDueDays: Int?
        /// 1 = critical  2 = high  3 = medium  4 = low (matches TaskPriority.rawValue)
        let priority: Int
        let estimatedMinutes: Int?
        let isRecurring: Bool
        let recurringInterval: RecurringInterval?
        let subtasks: [TemplateSubtask]
        let labels: [String]

        init(
            id: String = UUID().uuidString,
            title: String,
            notes: String? = nil,
            relativeDueDays: Int? = nil,
            priority: Int = 3,
            estimatedMinutes: Int? = nil,
            isRecurring: Bool = false,
            recurringInterval: RecurringInterval? = nil,
            subtasks: [TemplateSubtask] = [],
            labels: [String] = []
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.relativeDueDays = relativeDueDays
            self.priority = priority
            self.estimatedMinutes = estimatedMinutes
            self.isRecurring = isRecurring
            self.recurringInterval = recurringInterval
            self.subtasks = subtasks
            self.labels = labels
        }
    }

    struct TemplateSubtask: Codable, Identifiable {
        let id: String
        let title: String
        /// Days from template application date. nil = no due date.
        let relativeDueDays: Int?

        init(id: String = UUID().uuidString, title: String, relativeDueDays: Int? = nil) {
            self.id = id
            self.title = title
            self.relativeDueDays = relativeDueDays
        }
    }

    enum RecurringInterval: String, Codable {
        case daily, weekly, biweekly, monthly
    }
}
