// AIMessageModels.swift
// FlowDay
//
// Shared types for the Flow AI chat — messages, suggestion buttons,
// and the enum of actions those suggestions can trigger.

import Foundation

struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = .now
    var suggestions: [AISuggestion]? = nil
    /// Holds a pending task the user can confirm
    var pendingTask: AITaskSuggestion? = nil
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let action: AIAction
}

enum AIAction {
    case createTask(title: String)
    case confirmTask
    case planDay
    case breakdownGoal(goal: String)
    case generateTemplate(category: String)
    case suggestBreak
    case showProductivity
    case completeTask(id: UUID)
    case rescheduleTask(id: UUID, to: Date)
    case deleteTask(id: UUID)
    case changePriority(id: UUID, priority: Int)
    case addToProject(id: UUID, projectName: String)
    case executeNLAction(intent: NLTaskIntent)
}

struct NLTaskIntent: Codable {
    let intent: String        // "reschedule" | "complete" | "delete" | "change_priority" | "add_to_project" | "none"
    let taskId: String?       // first 8 chars of matching task id
    let taskTitle: String?
    let newDate: String?      // "YYYY-MM-DD"
    let newTime: String?      // "HH:mm"
    let newPriority: Int?
    let projectName: String?
    let confirmation: String
}
