// FocusTimerAttributes.swift
// ActivityAttributes for Focus Timer Live Activity
// Shared between FlowDay app (starts activity) and FlowDayWidgets (renders it)

import ActivityKit
import Foundation

struct FocusTimerAttributes: ActivityAttributes {

    // Dynamic state — changes with each update
    struct ContentState: Codable, Hashable {
        let sessionType: String     // "Focus", "Short Break", "Long Break"
        let startedAt: Date
        let durationMinutes: Int
        let taskTitle: String?

        var endTime: Date {
            startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }
        var isBreak: Bool { sessionType != "Focus" }
    }

    // Static metadata — set once at creation
    let initialTaskTitle: String?
}
