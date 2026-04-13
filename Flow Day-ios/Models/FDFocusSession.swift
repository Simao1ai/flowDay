// FDFocusSession.swift
// FlowDay — Built-in Pomodoro / focus timer

import Foundation
import SwiftData

@Model
final class FDFocusSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var durationMinutes: Int
    var type: SessionType
    var taskID: UUID?
    var wasCompleted: Bool

    init(durationMinutes: Int = 25, type: SessionType = .focus, taskID: UUID? = nil) {
        self.id = UUID()
        self.startedAt = .now
        self.endedAt = nil
        self.durationMinutes = durationMinutes
        self.type = type
        self.taskID = taskID
        self.wasCompleted = false
    }

    func complete() { endedAt = .now; wasCompleted = true }
    func abandon() { endedAt = .now; wasCompleted = false }
}

enum SessionType: String, Codable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var defaultMinutes: Int {
        switch self {
        case .focus: return 25
        case .shortBreak: return 5
        case .longBreak: return 15
        }
    }
}
