// AIPlanner.swift
// FlowDay
//
// Energy-aware AI scheduling — FlowDay's #1 differentiator.
// Analyzes tasks, energy level, and calendar gaps to build an
// optimized daily plan. No network calls — runs 100% on-device.

import Foundation
import SwiftData

struct AIScheduleSuggestion: Identifiable {
    let id = UUID()
    let task: FDTask
    let suggestedTime: Date
    let reason: String
}

struct AIPlanResult {
    let suggestions: [AIScheduleSuggestion]
    let summary: String
    let tips: [String]
}

final class AIPlanner {

    private let calendar = Calendar.current

    /// Generate an optimized daily plan based on energy and task properties
    func generatePlan(
        tasks: [FDTask],
        energyLevel: EnergyLevel?,
        existingEvents: [(start: Date, end: Date)] = []
    ) -> AIPlanResult {

        let energy = energyLevel ?? .normal
        let unscheduled = tasks.filter { !$0.isCompleted && !$0.isDeleted && $0.scheduledTime == nil }
        let today = Date.now

        guard !unscheduled.isEmpty else {
            return AIPlanResult(
                suggestions: [],
                summary: "All your tasks are already scheduled or completed. Nice work!",
                tips: ["Try adding new tasks to keep your momentum going."]
            )
        }

        // Sort tasks by priority (urgent first), then by estimated cognitive load
        let sorted = unscheduled.sorted { a, b in
            if a.priority != b.priority {
                return a.priority.rawValue < b.priority.rawValue
            }
            return (a.cognitiveLoad ?? 3) > (b.cognitiveLoad ?? 3)
        }

        // Determine available time slots based on energy
        let slots = availableSlots(for: energy, existing: existingEvents, on: today)
        var suggestions: [AIScheduleSuggestion] = []
        var slotIndex = 0

        for task in sorted {
            guard slotIndex < slots.count else { break }
            let slot = slots[slotIndex]
            let reason = reasonFor(task: task, slot: slot, energy: energy)

            suggestions.append(AIScheduleSuggestion(
                task: task,
                suggestedTime: slot,
                reason: reason
            ))
            slotIndex += 1
        }

        let summary = buildSummary(energy: energy, taskCount: suggestions.count, total: unscheduled.count)
        let tips = buildTips(energy: energy, tasks: sorted)

        return AIPlanResult(
            suggestions: suggestions,
            summary: summary,
            tips: tips
        )
    }

    /// Apply the plan: set scheduledTime on each suggested task
    func applyPlan(_ suggestions: [AIScheduleSuggestion], using context: ModelContext) {
        for suggestion in suggestions {
            suggestion.task.scheduledTime = suggestion.suggestedTime
            suggestion.task.aiSuggestedTime = suggestion.suggestedTime
            suggestion.task.modifiedAt = .now
        }
        try? context.save()
    }

    // MARK: - Slot Generation

    private func availableSlots(
        for energy: EnergyLevel,
        existing: [(start: Date, end: Date)],
        on date: Date
    ) -> [Date] {
        var slots: [Date] = []
        let cal = calendar

        // Define work windows based on energy
        guard let (peakStart, peakEnd, lightStart, lightEnd) = energyWindows(energy, on: date) else {
            return []
        }

        // Peak hours — for high-priority/complex tasks
        var current = peakStart
        while current < peakEnd && slots.count < 10 {
            if !conflictsWithExisting(time: current, existing: existing) {
                slots.append(current)
            }
            current = cal.date(byAdding: .minute, value: 45, to: current) ?? current
        }

        // Light hours — for low-priority/easy tasks
        current = lightStart
        while current < lightEnd && slots.count < 10 {
            if !conflictsWithExisting(time: current, existing: existing) {
                slots.append(current)
            }
            current = cal.date(byAdding: .minute, value: 30, to: current) ?? current
        }

        return slots
    }

    private func energyWindows(_ energy: EnergyLevel, on date: Date) -> (Date, Date, Date, Date)? {
        let cal = calendar
        switch energy {
        case .high:
            // High energy: deep work 8-12, light work 14-17
            guard let peakStart = cal.date(bySettingHour: 8, minute: 0, second: 0, of: date),
                  let peakEnd = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date),
                  let lightStart = cal.date(bySettingHour: 14, minute: 0, second: 0, of: date),
                  let lightEnd = cal.date(bySettingHour: 17, minute: 0, second: 0, of: date)
            else { return nil }
            return (peakStart, peakEnd, lightStart, lightEnd)

        case .normal:
            // Normal: balanced 9-12, 14-16
            guard let peakStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date),
                  let peakEnd = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date),
                  let lightStart = cal.date(bySettingHour: 14, minute: 0, second: 0, of: date),
                  let lightEnd = cal.date(bySettingHour: 16, minute: 0, second: 0, of: date)
            else { return nil }
            return (peakStart, peakEnd, lightStart, lightEnd)

        case .low:
            // Low energy: shorter windows, later start 10-11:30, 14-15
            guard let peakStart = cal.date(bySettingHour: 10, minute: 0, second: 0, of: date),
                  let peakEnd = cal.date(bySettingHour: 11, minute: 30, second: 0, of: date),
                  let lightStart = cal.date(bySettingHour: 14, minute: 0, second: 0, of: date),
                  let lightEnd = cal.date(bySettingHour: 15, minute: 0, second: 0, of: date)
            else { return nil }
            return (peakStart, peakEnd, lightStart, lightEnd)
        }
    }

    private func conflictsWithExisting(time: Date, existing: [(start: Date, end: Date)]) -> Bool {
        for event in existing {
            if time >= event.start && time < event.end {
                return true
            }
        }
        return false
    }

    // MARK: - Reasoning

    private func reasonFor(task: FDTask, slot: Date, energy: EnergyLevel) -> String {
        let hour = calendar.component(.hour, from: slot)
        let isMorning = hour < 12

        if task.priority == .urgent || task.priority == .high {
            if isMorning {
                return "Scheduled during your peak focus hours — high priority tasks first."
            } else {
                return "Important task slotted after lunch — tackle it before energy dips."
            }
        }

        if let mins = task.estimatedMinutes, mins <= 15 {
            return "Quick task — perfect for a transition moment between blocks."
        }

        if energy == .low {
            return "Placed in a gentle time slot to match your energy today."
        }

        if isMorning {
            return "Morning slot for steady focus — your brain is fresh."
        } else {
            return "Afternoon slot — good for lighter or creative work."
        }
    }

    private func buildSummary(energy: EnergyLevel, taskCount: Int, total: Int) -> String {
        let energyText: String
        switch energy {
        case .high:
            energyText = "You're feeling energized"
        case .normal:
            energyText = "It's a balanced day"
        case .low:
            energyText = "Taking it easy today"
        }

        if taskCount == total {
            return "\(energyText) — I've scheduled all \(taskCount) unplanned tasks into your day."
        } else {
            return "\(energyText) — I've scheduled \(taskCount) of \(total) tasks. The rest can wait for another day."
        }
    }

    private func buildTips(energy: EnergyLevel, tasks: [FDTask]) -> [String] {
        var tips: [String] = []

        switch energy {
        case .high:
            tips.append("Great energy! Front-load your hardest tasks this morning.")
        case .normal:
            tips.append("Alternate between deep work and lighter tasks for balance.")
        case .low:
            tips.append("Be kind to yourself — focus on just 2-3 essential tasks today.")
        }

        let urgentCount = tasks.filter { $0.priority == .urgent }.count
        if urgentCount > 2 {
            tips.append("You have \(urgentCount) urgent tasks — consider if any can be delegated.")
        }

        let totalMinutes = tasks.compactMap(\.estimatedMinutes).reduce(0, +)
        if totalMinutes > 360 {
            tips.append("Over 6 hours of estimated work — plan breaks every 90 minutes.")
        }

        return tips
    }
}
