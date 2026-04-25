// AutoScheduleService.swift
// FlowDay — Wave 5b
//
// Sends unscheduled tasks + calendar blocks + energy to Claude and returns
// an AI-generated weekly schedule. No Supabase SDK — uses ClaudeClient only.

import Foundation
import Observation

// MARK: - Models

struct TimeBlock: Identifiable {
    let id: UUID
    let taskID: UUID
    let taskTitle: String
    let time: Date
    let reason: String
    var isAccepted: Bool = true
}

struct ScheduledDay: Identifiable {
    let id: UUID
    let date: Date
    var blocks: [TimeBlock]

    var dayLabel: String {
        date.formatted(.dateTime.weekday(.wide))
    }
    var dateLabel: String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct ScheduledWeek {
    var days: [ScheduledDay]
}

// MARK: - AutoScheduleService

@MainActor
@Observable
final class AutoScheduleService {

    var isLoading = false
    var schedule: ScheduledWeek?
    var errorMessage: String?

    // MARK: - Generate

    func generateSchedule(
        tasks: [FDTask],
        calendarEvents: [(start: Date, end: Date, title: String)],
        energyLevel: EnergyLevel?
    ) async {
        isLoading = true
        errorMessage = nil
        schedule = nil
        defer { isLoading = false }

        let unscheduled = tasks.filter { !$0.isDeleted && !$0.isCompleted && $0.scheduledTime == nil }
        guard !unscheduled.isEmpty else {
            schedule = ScheduledWeek(days: [])
            return
        }

        let prompt = buildPrompt(tasks: unscheduled, events: calendarEvents, energy: energyLevel)

        do {
            let response = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.4,
                maxTokens: 2048
            )
            schedule = parseResponse(response, tasks: unscheduled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apply

    func applyAccepted(allTasks: [FDTask], using taskService: TaskService) {
        guard let schedule else { return }
        for day in schedule.days {
            for block in day.blocks where block.isAccepted {
                if let task = allTasks.first(where: { $0.id == block.taskID }) {
                    taskService.rescheduleTask(task, to: block.time)
                }
            }
        }
    }

    func rejectBlock(id: UUID) {
        guard var week = schedule else { return }
        for i in week.days.indices {
            if let j = week.days[i].blocks.firstIndex(where: { $0.id == id }) {
                week.days[i].blocks[j].isAccepted = false
            }
        }
        schedule = week
    }

    func acceptAll() {
        guard var week = schedule else { return }
        for i in week.days.indices {
            for j in week.days[i].blocks.indices {
                week.days[i].blocks[j].isAccepted = true
            }
        }
        schedule = week
    }

    var acceptedCount: Int {
        schedule?.days.flatMap(\.blocks).filter(\.isAccepted).count ?? 0
    }

    // MARK: - Prompt

    private func buildPrompt(
        tasks: [FDTask],
        events: [(start: Date, end: Date, title: String)],
        energy: EnergyLevel?
    ) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let dayOfWeek = Date.now.formatted(.dateTime.weekday(.wide))
        let energyLabel = energy?.label ?? "normal"

        let taskLines = tasks.prefix(20).map { t in
            let idStr = String(t.id.uuidString.prefix(8))
            let pri = t.priority.label
            let mins = t.estimatedMinutes.map { "\($0)m" } ?? "?"
            return "- [\(idStr)] \(t.title) | \(pri) | \(mins)"
        }.joined(separator: "\n")

        let eventLines = events.isEmpty ? "None" : events.prefix(20).map { e in
            let start = e.start.formatted(.dateTime.weekday(.short).hour().minute())
            let end = e.end.formatted(.dateTime.hour().minute())
            return "- \(start)–\(end): \(e.title)"
        }.joined(separator: "\n")

        let daysLine = weekDays.map {
            $0.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }.joined(separator: ", ")

        return """
        Today is \(dayOfWeek). Week: \(daysLine).
        User energy: \(energyLabel). High energy windows: 9am–12pm and 3pm–5pm.

        Tasks to schedule (8-char ID prefix | title | priority | estimate):
        \(taskLines)

        Existing calendar blocks (blocked time):
        \(eventLines)

        Schedule these tasks into the next 7 days. Rules:
        - Prefer 9am–12pm for urgent/high priority tasks
        - Prefer 2pm–5pm for medium/low priority tasks
        - Never schedule during blocked calendar time
        - Space tasks with at least 30 min between them
        - Max 5 tasks per day
        - Give a short reason per block (≤10 words)

        Respond ONLY with valid JSON, no markdown fences, no explanation:
        {"schedule":[{"date":"YYYY-MM-DD","blocks":[{"taskIDPrefix":"12345678","taskTitle":"...","time":"HH:MM","reason":"..."}]}]}
        """
    }

    // MARK: - Parse

    private func parseResponse(_ response: String, tasks: [FDTask]) -> ScheduledWeek {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences if the model wrapped it
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scheduleArray = json["schedule"] as? [[String: Any]]
        else {
            return ScheduledWeek(days: [])
        }

        let cal = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var days: [ScheduledDay] = []

        for dayJSON in scheduleArray {
            guard let dateString = dayJSON["date"] as? String,
                  let dayDate = dateFormatter.date(from: dateString),
                  let blocksArray = dayJSON["blocks"] as? [[String: Any]]
            else { continue }

            var blocks: [TimeBlock] = []
            for blockJSON in blocksArray {
                guard let idPrefix = blockJSON["taskIDPrefix"] as? String,
                      let timeString = blockJSON["time"] as? String,
                      let taskTitle = blockJSON["taskTitle"] as? String,
                      let parsedTime = timeFormatter.date(from: timeString),
                      let matchedTask = tasks.first(where: {
                          $0.id.uuidString.uppercased().hasPrefix(idPrefix.uppercased())
                      })
                else { continue }

                let reason = (blockJSON["reason"] as? String) ?? ""
                let timeComps = cal.dateComponents([.hour, .minute], from: parsedTime)
                var combined = cal.dateComponents([.year, .month, .day], from: dayDate)
                combined.hour = timeComps.hour
                combined.minute = timeComps.minute
                guard let finalDate = cal.date(from: combined) else { continue }

                blocks.append(TimeBlock(
                    id: UUID(),
                    taskID: matchedTask.id,
                    taskTitle: taskTitle,
                    time: finalDate,
                    reason: reason
                ))
            }

            if !blocks.isEmpty {
                days.append(ScheduledDay(id: UUID(), date: dayDate, blocks: blocks))
            }
        }

        return ScheduledWeek(days: days)
    }
}
