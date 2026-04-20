// TemplateV2.swift
// FlowDay
//
// Richer template format modeled on Todoist's premium Project Tracker.
// Supports phases/sections, rich task notes, relative due dates, subtasks
// with milestones, and recurring tasks. Older TemplateItem-based templates
// continue to work through the catalog — V2 templates live side-by-side.

import Foundation
import SwiftUI

// MARK: - V2 Template

struct TemplateV2: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let icon: String
    let color: Color
    let category: String

    /// Optional "How to use this template" block shown as a non-completable
    /// info task at the top of the project.
    let intro: TemplateIntro?

    /// Ordered sections (phases). Each becomes a section header inside the
    /// project. A nil-key bucket is never created — every V2 task belongs
    /// to exactly one section.
    let sections: [TemplateSection]
}

struct TemplateIntro {
    let title: String
    let paragraphs: [String]
}

struct TemplateSection {
    let name: String
    let emoji: String
    let description: String?
    let tasks: [TemplateTaskV2]
}

struct TemplateTaskV2 {
    let title: String
    let notes: String?
    let priority: TaskPriority
    let estimatedMinutes: Int?
    /// Days offset from the template-apply date. 0 = today, 7 = next week.
    let relativeDueDay: Int?
    /// Hour + minute for scheduledTime (24-hour). nil = no scheduled time.
    let scheduledHour: Int?
    let scheduledMinute: Int?
    let recurrenceRule: String?
    let labels: [String]
    let subtasks: [TemplateSubtaskV2]

    init(
        title: String,
        notes: String? = nil,
        priority: TaskPriority = .medium,
        estimatedMinutes: Int? = nil,
        relativeDueDay: Int? = nil,
        scheduledHour: Int? = nil,
        scheduledMinute: Int? = nil,
        recurrenceRule: String? = nil,
        labels: [String] = [],
        subtasks: [TemplateSubtaskV2] = []
    ) {
        self.title = title
        self.notes = notes
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.relativeDueDay = relativeDueDay
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.recurrenceRule = recurrenceRule
        self.labels = labels
        self.subtasks = subtasks
    }
}

struct TemplateSubtaskV2 {
    let title: String
    let notes: String?
    let relativeDueDay: Int?
    let estimatedMinutes: Int?

    init(
        title: String,
        notes: String? = nil,
        relativeDueDay: Int? = nil,
        estimatedMinutes: Int? = nil
    ) {
        self.title = title
        self.notes = notes
        self.relativeDueDay = relativeDueDay
        self.estimatedMinutes = estimatedMinutes
    }
}
