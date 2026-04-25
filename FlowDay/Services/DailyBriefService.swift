// DailyBriefService.swift
// FlowDay — Generates a personalized morning briefing via Claude, cached once per day.

import Foundation
import Observation

struct DailyBrief: Codable {
    let greeting: String
    let topPriority: String
    let scheduleSummary: String
    let streakMessage: String
    let motivationalLine: String
    let generatedDate: Date
}

@Observable @MainActor
final class DailyBriefService {

    static let shared = DailyBriefService()

    private(set) var brief: DailyBrief? = nil
    private(set) var isLoading = false
    private(set) var error: String? = nil

    private let cacheKey = "daily_brief_cache"

    private init() { loadCached() }

    // MARK: - Generate

    func generateIfNeeded(tasks: [FDTask], habits: [FDHabit], streak: Int) async {
        // Use cached brief if generated today
        if let existing = brief, Calendar.current.isDateInToday(existing.generatedDate) { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let cal = Calendar.current
        let todayStr = Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let hour = cal.component(.hour, from: .now)
        let greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"

        let todayTasks = tasks.filter { $0.isScheduledToday && !$0.isCompleted }
        let topTask = todayTasks.sorted { ($0.priority.rawValue) > ($1.priority.rawValue) }.first?.title ?? "nothing scheduled yet"
        let taskCount = todayTasks.count
        let habitCount = habits.filter(\.isDueToday).count

        let prompt = """
        Generate a short personal daily briefing for \(todayStr).

        Context:
        - \(taskCount) tasks scheduled today, top priority: "\(topTask)"
        - \(habitCount) habits due today
        - Current streak: \(streak) days

        Return ONLY a JSON object (no markdown, no code blocks) with exactly these keys:
        {
          "greeting": "\(greeting), [first name or 'there']",
          "topPriority": "One sentence about the most important task",
          "scheduleSummary": "One sentence summarizing the day's load",
          "streakMessage": "One sentence celebrating or encouraging the streak (use 🔥 emoji)",
          "motivationalLine": "One short motivational sentence for the day"
        }
        """

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .dayRecap,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.7,
                maxTokens: 300
            )

            // Parse JSON from response
            guard let data = raw.data(using: .utf8),
                  let json = try? JSONDecoder().decode([String: String].self, from: data) else {
                // Fallback brief if parsing fails
                brief = DailyBrief(
                    greeting: "\(greeting), there!",
                    topPriority: "Focus on \(topTask) first.",
                    scheduleSummary: "You have \(taskCount) tasks and \(habitCount) habits today.",
                    streakMessage: streak > 0 ? "🔥 \(streak)-day streak! Keep it going." : "Start your streak today!",
                    motivationalLine: "Make today count.",
                    generatedDate: .now
                )
                saveCached()
                return
            }

            brief = DailyBrief(
                greeting: json["greeting"] ?? "\(greeting), there!",
                topPriority: json["topPriority"] ?? "Focus on \(topTask) first.",
                scheduleSummary: json["scheduleSummary"] ?? "You have \(taskCount) tasks today.",
                streakMessage: json["streakMessage"] ?? "🔥 Keep your streak alive!",
                motivationalLine: json["motivationalLine"] ?? "Make today count.",
                generatedDate: .now
            )
            saveCached()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Cache

    private func saveCached() {
        guard let b = brief, let data = try? JSONEncoder().encode(b) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(DailyBrief.self, from: data),
              Calendar.current.isDateInToday(decoded.generatedDate) else { return }
        brief = decoded
    }
}
