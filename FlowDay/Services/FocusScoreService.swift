// FocusScoreService.swift
// FlowDay — Wave 5b
//
// Calculates a daily Focus Score (0–100) from task completions, focus time,
// habits, and energy alignment. Stores 30 days of history in UserDefaults.

import Foundation
import Observation

// MARK: - Score Breakdown

struct FocusScoreBreakdown {
    var taskPoints: Int       // 0–40
    var focusPoints: Int      // 0–25
    var habitPoints: Int      // 0–20
    var energyPoints: Int     // 0–15

    var total: Int { taskPoints + focusPoints + habitPoints + energyPoints }
}

// MARK: - Weekly Report Data

struct WeeklyScoreReport {
    let weekScore: Int
    let previousWeekScore: Int
    let trend: Int                 // positive = improved
    let dailyBreakdowns: [(date: Date, score: Int)]
    let totalTasksCompleted: Int
    let totalFocusMinutes: Int
    let habitHitRate: Double       // 0.0–1.0
}

// MARK: - FocusScoreService

@MainActor
@Observable
final class FocusScoreService {

    static let shared = FocusScoreService()

    var todayScore: Int = 0
    var todayBreakdown: FocusScoreBreakdown = FocusScoreBreakdown(
        taskPoints: 0, focusPoints: 0, habitPoints: 0, energyPoints: 0
    )
    var weeklyReport: WeeklyScoreReport?
    var aiRecommendation: String?
    var isLoadingAI = false

    private let storageKey = "fd_focus_scores"       // [String: Int] date → score
    private let focusTargetMinutes = 120              // 2-hour daily focus target

    private init() {
        loadTodayScore()
    }

    // MARK: - Calculate Daily Score

    func calculateDailyScore(
        tasks: [FDTask],
        focusSessions: [FDFocusSession],
        habits: [FDHabit],
        energy: EnergyLevel?
    ) {
        let cal = Calendar.current
        let breakdown = computeBreakdown(tasks: tasks, focusSessions: focusSessions, habits: habits, energy: energy, cal: cal)
        todayBreakdown = breakdown
        todayScore = breakdown.total
        persistScore(breakdown.total, for: .now)
    }

    private func computeBreakdown(
        tasks: [FDTask],
        focusSessions: [FDFocusSession],
        habits: [FDHabit],
        energy: EnergyLevel?,
        cal: Calendar
    ) -> FocusScoreBreakdown {
        // Task component: 40 pts max
        let todayTasks = tasks.filter { !$0.isDeleted && $0.isScheduledToday }
        let completedToday = todayTasks.filter(\.isCompleted)
        let planned = max(todayTasks.count, 1)
        let taskRatio = min(Double(completedToday.count) / Double(planned), 1.0)
        let taskPoints = Int(taskRatio * 40)

        // Focus component: 25 pts max
        let todaySessions = focusSessions.filter {
            $0.type == .focus && $0.wasCompleted &&
            cal.isDateInToday($0.startedAt)
        }
        let focusMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let focusRatio = min(Double(focusMinutes) / Double(focusTargetMinutes), 1.0)
        let focusPoints = Int(focusRatio * 25)

        // Habit component: 20 pts max
        let dueHabits = habits.filter { $0.isActive && $0.isDueToday }
        let doneHabits = dueHabits.filter(\.isCompletedToday)
        let habitRatio = dueHabits.isEmpty ? 1.0 : min(Double(doneHabits.count) / Double(dueHabits.count), 1.0)
        let habitPoints = Int(habitRatio * 20)

        // Energy alignment: 15 pts max
        // Full points if energy was logged + high-priority tasks completed in morning
        var energyPoints = 0
        if energy != nil {
            energyPoints = 8 // logged energy
            let urgentDone = completedToday.filter { $0.priority == .urgent || $0.priority == .high }
            if !urgentDone.isEmpty {
                energyPoints = 15
            } else if !completedToday.isEmpty {
                energyPoints = 12
            }
        }

        return FocusScoreBreakdown(
            taskPoints: taskPoints,
            focusPoints: focusPoints,
            habitPoints: habitPoints,
            energyPoints: energyPoints
        )
    }

    // MARK: - Weekly Report

    func buildWeeklyReport(tasks: [FDTask], focusSessions: [FDFocusSession], habits: [FDHabit]) -> WeeklyScoreReport {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let thisWeekDates = (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let prevWeekDates = (7..<14).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }

        let stored = loadStoredScores()

        func scoreFor(_ date: Date) -> Int {
            let key = dateKey(for: date)
            return stored[key] ?? 0
        }

        let thisWeekScores = thisWeekDates.map { scoreFor($0) }
        let prevWeekScores = prevWeekDates.map { scoreFor($0) }

        let thisAvg = thisWeekScores.isEmpty ? 0 : thisWeekScores.reduce(0, +) / thisWeekScores.count
        let prevAvg = prevWeekScores.isEmpty ? 0 : prevWeekScores.reduce(0, +) / prevWeekScores.count

        let dailyBreakdowns = thisWeekDates.reversed().map { date in
            (date: date, score: scoreFor(date))
        }

        // Stats for the week
        let completedThisWeek = tasks.filter { task in
            guard !task.isDeleted, task.isCompleted, let at = task.completedAt else { return false }
            return thisWeekDates.contains { cal.isDate($0, inSameDayAs: at) }
        }

        let focusThisWeek = focusSessions.filter { session in
            guard session.type == .focus, session.wasCompleted else { return false }
            return thisWeekDates.contains { cal.isDate($0, inSameDayAs: session.startedAt) }
        }
        let totalFocusMins = focusThisWeek.reduce(0) { $0 + $1.durationMinutes }

        let activeHabits = habits.filter(\.isActive)
        let habitHitRate: Double = activeHabits.isEmpty ? 0.0 : min(
            Double(activeHabits.filter(\.isCompletedToday).count) / Double(max(activeHabits.count, 1)),
            1.0
        )

        let report = WeeklyScoreReport(
            weekScore: thisAvg,
            previousWeekScore: prevAvg,
            trend: thisAvg - prevAvg,
            dailyBreakdowns: dailyBreakdowns,
            totalTasksCompleted: completedThisWeek.count,
            totalFocusMinutes: totalFocusMins,
            habitHitRate: habitHitRate
        )
        weeklyReport = report
        return report
    }

    // MARK: - AI Recommendation

    func generateRecommendation(report: WeeklyScoreReport, tasks: [FDTask]) async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        let topTasks = tasks
            .filter { $0.isCompleted && !$0.isDeleted }
            .prefix(3)
            .map(\.title)
            .joined(separator: ", ")

        let prompt = """
        Weekly productivity summary:
        - Focus Score: \(report.weekScore)/100 (was \(report.previousWeekScore) last week, trend: \(report.trend > 0 ? "+" : "")\(report.trend))
        - Tasks completed: \(report.totalTasksCompleted)
        - Focus time: \(report.totalFocusMinutes) minutes
        - Habit hit rate: \(Int(report.habitHitRate * 100))%
        - Top accomplishments: \(topTasks.isEmpty ? "none logged" : topTasks)

        Write 2 concise sentences: one observation about the week, one actionable recommendation for next week. Be specific and encouraging.
        """

        do {
            aiRecommendation = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.7,
                maxTokens: 200
            )
        } catch {
            aiRecommendation = nil
        }
    }

    // MARK: - Score Color

    func color(for score: Int) -> ScoreColor {
        switch score {
        case 80...100: return .excellent
        case 60...79:  return .good
        case 40...59:  return .fair
        default:       return .low
        }
    }

    enum ScoreColor {
        case excellent, good, fair, low
    }

    // MARK: - Persistence

    private func persistScore(_ score: Int, for date: Date) {
        var stored = loadStoredScores()
        stored[dateKey(for: date)] = score

        // Trim to 30 days
        if stored.count > 30 {
            let sorted = stored.keys.sorted()
            let toRemove = sorted.prefix(stored.count - 30)
            toRemove.forEach { stored.removeValue(forKey: $0) }
        }

        UserDefaults.standard.set(stored, forKey: storageKey)
    }

    private func loadStoredScores() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int]) ?? [:]
    }

    private func loadTodayScore() {
        let stored = loadStoredScores()
        todayScore = stored[dateKey(for: .now)] ?? 0
    }

    private func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
