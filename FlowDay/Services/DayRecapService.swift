// DayRecapService.swift
// FlowDay
// Fetches today's data and calls the Edge Function to generate a motivational
// end-of-day recap using Claude. Feature .flowAI reuses the same system prompt
// as the chat; the user message provides all the context.

import Foundation
import Observation

@MainActor
@Observable
final class DayRecapService {
    var isLoading = false
    var summary: String?
    var error: String?

    func generateRecap(tasks: [FDTask], habits: [FDHabit], energy: EnergyLevel?) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let cal = Calendar.current

        let completedToday = tasks.filter {
            $0.isCompleted && $0.completedAt.map { cal.isDateInToday($0) } == true
        }
        let dueHabits = habits.filter(\.isDueToday)
        let doneHabits = habits.filter(\.isCompletedToday)

        let taskList = completedToday.prefix(7).map(\.title).joined(separator: ", ")
        let energyLabel = energy?.label ?? "not logged"

        let prompt = """
        My end-of-day summary for \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())):
        - Completed \(completedToday.count) task(s): \(taskList.isEmpty ? "none" : taskList)
        - Habits done: \(doneHabits.count) of \(dueHabits.count)
        - Energy level: \(energyLabel)

        Write a warm, personal 3-sentence motivational recap of my day. Be specific about what I accomplished. End with encouragement for tomorrow. Keep it concise.
        """

        do {
            summary = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.8,
                maxTokens: 300
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
