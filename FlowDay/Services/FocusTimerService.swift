// FocusTimerService.swift
// FlowDay — Pomodoro focus timer state machine

import Foundation
import UIKit
import UserNotifications

// MARK: - Phase

enum TimerPhase: Equatable {
    case idle
    case working
    case shortBreak
    case longBreak
    case paused(resumingTo: TimerPhaseType)
}

enum TimerPhaseType: Equatable {
    case working
    case shortBreak
    case longBreak
}

// MARK: - Service

@Observable
final class FocusTimerService {

    // State
    var phase: TimerPhase = .idle
    var secondsRemaining: Int = 0
    var currentPhaseTotalSeconds: Int = 0
    var completedInCycle: Int = 0   // 0–4; resets after long break
    var linkedTaskID: UUID? = nil

    // Session tracking (observed by FocusTimerView to persist sessions)
    var completedSessionCount: Int = 0

    private var timer: Timer? = nil
    private var backgroundEntryTime: Date? = nil
    private var notificationID: String? = nil

    // MARK: - Computed durations (reads UserDefaults each time)

    var workSeconds: Int       { UserDefaults.standard.integer(forKey: "focus_work_minutes").nonZero(or: 25) * 60 }
    var shortBreakSeconds: Int { UserDefaults.standard.integer(forKey: "focus_short_break_minutes").nonZero(or: 5) * 60 }
    var longBreakSeconds: Int  { UserDefaults.standard.integer(forKey: "focus_long_break_minutes").nonZero(or: 15) * 60 }

    // Convenience booleans for TodayView header indicator
    var isActive: Bool  { phase != .idle }
    var isRunning: Bool {
        switch phase {
        case .working, .shortBreak, .longBreak: return true
        default: return false
        }
    }

    // MARK: - Init

    init() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(didResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    // MARK: - Controls

    func start(linkedTask: UUID? = nil) {
        linkedTaskID = linkedTask
        beginWorkPhase()
    }

    func pauseResume() {
        switch phase {
        case .working:                      pauseTimer(resumingTo: .working)
        case .shortBreak:                   pauseTimer(resumingTo: .shortBreak)
        case .longBreak:                    pauseTimer(resumingTo: .longBreak)
        case .paused(let r):                resumePhase(r)
        case .idle:                         break
        }
    }

    func skipBreak() {
        guard case .shortBreak = phase else {
            if case .longBreak = phase { cancelTimer(); beginWorkPhase() }
            return
        }
        cancelTimer()
        beginWorkPhase()
    }

    func stop() {
        cancelTimer()
        cancelPendingNotification()
        phase = .idle
        secondsRemaining = 0
        currentPhaseTotalSeconds = 0
        linkedTaskID = nil
    }

    // MARK: - Private Phase Transitions

    private func beginWorkPhase() {
        let total = workSeconds
        currentPhaseTotalSeconds = total
        secondsRemaining = total
        phase = .working
        startTicking()
        Haptics.tock()
    }

    private func beginShortBreak() {
        let total = shortBreakSeconds
        currentPhaseTotalSeconds = total
        secondsRemaining = total
        phase = .shortBreak
        startTicking()
        Haptics.success()
    }

    private func beginLongBreak() {
        let total = longBreakSeconds
        currentPhaseTotalSeconds = total
        secondsRemaining = total
        phase = .longBreak
        startTicking()
        Haptics.success()
    }

    private func pauseTimer(resumingTo type: TimerPhaseType) {
        cancelTimer()
        cancelPendingNotification()
        phase = .paused(resumingTo: type)
        Haptics.pick()
    }

    private func resumePhase(_ type: TimerPhaseType) {
        switch type {
        case .working:    phase = .working
        case .shortBreak: phase = .shortBreak
        case .longBreak:  phase = .longBreak
        }
        startTicking()
        Haptics.tap()
    }

    // MARK: - Timer

    private func startTicking() {
        cancelTimer()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard secondsRemaining > 0 else { phaseCompleted(); return }
        secondsRemaining -= 1
    }

    // MARK: - Phase Completion

    private func phaseCompleted() {
        cancelTimer()
        switch phase {
        case .working:
            completedSessionCount += 1
            completedInCycle = min(completedInCycle + 1, 4)
            Haptics.success()
            if completedInCycle >= 4 {
                completedInCycle = 0
                beginLongBreak()
            } else {
                beginShortBreak()
            }
        case .shortBreak, .longBreak:
            Haptics.tock()
            beginWorkPhase()
        case .idle, .paused:
            break
        }
    }

    // MARK: - Background Handling

    @objc private func didResignActive() {
        guard isRunning else { return }
        backgroundEntryTime = .now
        let phaseName: String
        switch phase {
        case .working:    phaseName = "Focus session"
        case .shortBreak: phaseName = "Short break"
        case .longBreak:  phaseName = "Long break"
        default:          return
        }
        scheduleNotification(secondsFromNow: secondsRemaining, phaseName: phaseName)
        cancelTimer()
    }

    @objc private func didBecomeActive() {
        cancelPendingNotification()
        guard let entry = backgroundEntryTime else { return }
        backgroundEntryTime = nil
        let elapsed = Int(Date.now.timeIntervalSince(entry))
        secondsRemaining = max(0, secondsRemaining - elapsed)
        if secondsRemaining == 0 {
            phaseCompleted()
        } else {
            startTicking()
        }
    }

    // MARK: - Notifications

    private func scheduleNotification(secondsFromNow: Int, phaseName: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let id = UUID().uuidString
        notificationID = id
        let content = UNMutableNotificationContent()
        content.title = "\(phaseName) complete!"
        content.body = "Time to switch. Tap to open FlowDay."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, secondsFromNow)), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger),
            withCompletionHandler: nil
        )
    }

    private func cancelPendingNotification() {
        if let id = notificationID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            notificationID = nil
        }
    }
}

// MARK: - Helpers

private extension Int {
    func nonZero(or fallback: Int) -> Int { self == 0 ? fallback : self }
}
