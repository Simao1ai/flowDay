// FocusTimerService.swift
// FlowDay — Pomodoro-style focus timer engine

import Foundation
import SwiftData
import UserNotifications

@Observable
@MainActor
final class FocusTimerService {

    // MARK: - State

    var phase: SessionType = .focus
    var timeRemaining: Int = SessionType.focus.defaultMinutes * 60
    var isRunning: Bool = false
    var isActive: Bool = false  // true while a session exists (running or paused)
    var linkedTask: FDTask? = nil
    var focusSessionsToday: Int = 0

    var modelContext: ModelContext? {
        didSet { if modelContext != nil { loadTodaySessions() } }
    }

    private var currentSession: FDFocusSession?
    private var timer: Timer?

    // MARK: - Init

    init() {
        Task { await requestNotificationPermission() }
    }

    // MARK: - Computed

    var totalSeconds: Int { phase.defaultMinutes * 60 }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, Double(totalSeconds - timeRemaining) / Double(totalSeconds)))
    }

    var formattedTime: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    // MARK: - Controls

    func start(task: FDTask? = nil) {
        linkedTask = task
        if let ctx = modelContext {
            let session = FDFocusSession(
                durationMinutes: phase.defaultMinutes,
                type: phase,
                taskID: task?.id
            )
            ctx.insert(session)
            try? ctx.save()
            currentSession = session
        }
        isRunning = true
        isActive = true
        scheduleNotification(seconds: timeRemaining)
        startTimer()
    }

    func pause() {
        isRunning = false
        stopTimer()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fd-focus"])
    }

    func resume() {
        isRunning = true
        scheduleNotification(seconds: timeRemaining)
        startTimer()
    }

    func stop() {
        currentSession?.abandon()
        try? modelContext?.save()
        clearState()
    }

    func skipToNext() {
        completeCurrentSession()
        advancePhase()
    }

    // MARK: - Private

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning else { return }
        if timeRemaining > 1 {
            timeRemaining -= 1
        } else {
            timeRemaining = 0
            Haptics.success()
            completeCurrentSession()
            advancePhase()
        }
    }

    private func completeCurrentSession() {
        currentSession?.complete()
        if phase == .focus { focusSessionsToday += 1 }
        try? modelContext?.save()
        currentSession = nil
    }

    private func advancePhase() {
        stopTimer()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fd-focus"])

        let next: SessionType
        if phase == .focus {
            next = (focusSessionsToday % 4 == 0) ? .longBreak : .shortBreak
        } else {
            next = .focus
        }
        phase = next
        timeRemaining = next.defaultMinutes * 60
        isRunning = false
        isActive = false
    }

    private func clearState() {
        stopTimer()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fd-focus"])
        timeRemaining = phase.defaultMinutes * 60
        isRunning = false
        isActive = false
        currentSession = nil
        linkedTask = nil
    }

    func loadTodaySessions() {
        guard let ctx = modelContext else { return }
        let all = (try? ctx.fetch(FetchDescriptor<FDFocusSession>())) ?? []
        let cal = Calendar.current
        focusSessionsToday = all.filter {
            $0.type == .focus && $0.wasCompleted && cal.isDateInToday($0.startedAt)
        }.count
    }

    private func scheduleNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fd-focus"])
        let content = UNMutableNotificationContent()
        content.title = "\(phase.rawValue) complete!"
        content.body = phase == .focus
            ? "Time for a break — great work!"
            : "Break's over. Ready to focus?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, Double(seconds)),
            repeats: false
        )
        center.add(UNNotificationRequest(
            identifier: "fd-focus",
            content: content,
            trigger: trigger
        ))
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }
}
