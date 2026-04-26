// FocusLiveActivityManager.swift
// FlowDay — Manages the Focus Timer Live Activity

import ActivityKit
import Foundation

final class FocusLiveActivityManager {

    static let shared = FocusLiveActivityManager()
    private var currentActivity: Activity<FocusTimerAttributes>?

    private init() {}

    // MARK: - Start

    func start(sessionType: String, durationMinutes: Int, taskTitle: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs   = FocusTimerAttributes(initialTaskTitle: taskTitle)
        let state   = FocusTimerAttributes.ContentState(
            sessionType: sessionType,
            startedAt: .now,
            durationMinutes: durationMinutes,
            taskTitle: taskTitle
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
        } catch {
            print("[FocusLiveActivity] start failed: \(error)")
        }
    }

    // MARK: - Update

    func update(sessionType: String, durationMinutes: Int, taskTitle: String?) {
        guard let activity = currentActivity else {
            start(sessionType: sessionType, durationMinutes: durationMinutes, taskTitle: taskTitle)
            return
        }
        let state = FocusTimerAttributes.ContentState(
            sessionType: sessionType,
            startedAt: .now,
            durationMinutes: durationMinutes,
            taskTitle: taskTitle
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    // MARK: - Stop

    func stop() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
