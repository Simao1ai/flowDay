// DayRecapService.swift
// FlowDay

import Foundation

@Observable
@MainActor
final class DayRecapService {
    var isLoading = false
    var recap: String?
    var error: String?

    func generateRecap(
        completedTasks: [FDTask],
        habitsCompleted: Int,
        habitsTotal: Int,
        energyLevel: EnergyLevel?
    ) async {
        isLoading = true
        error = nil
        recap = nil
        defer { isLoading = false }

        let taskLines = completedTasks.prefix(10).map { "• \($0.title)" }.joined(separator: "\n")
        let energyText = energyLevel.map { "\($0.rawValue) (\($0.emoji))" } ?? "not logged"

        let prompt = """
        You are FlowDay's end-of-day assistant. Write a warm, personal 3-sentence recap.

        Today's data:
        - Tasks completed: \(completedTasks.count)\(completedTasks.isEmpty ? "" : "\n\(taskLines)")
        - Habits: \(habitsCompleted) of \(habitsTotal) completed
        - Energy level: \(energyText)

        Rules:
        1. Sentence 1: acknowledge what was accomplished specifically (use actual task/habit counts).
        2. Sentence 2: reflect on the day's energy and momentum.
        3. Sentence 3: brief encouragement for tomorrow. Keep it human, not corporate.
        Output only the 3 sentences — no titles, no bullet points.
        """

        do {
            let result = try await ClaudeClient.shared.chat(
                feature: .dayRecap,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.8,
                maxTokens: 300
            )
            self.recap = result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension EnergyLevel {
    var emoji: String {
        switch self {
        case .high:   "⚡"
        case .normal: "☀️"
        case .low:    "🌙"
        }
    }
}
