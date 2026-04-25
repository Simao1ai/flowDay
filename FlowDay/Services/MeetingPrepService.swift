// MeetingPrepService.swift
// FlowDay
//
// Pro feature: 30 minutes before a calendar meeting, auto-generate a prep
// card with talking points, questions to ask, and relevant context.
// Gated behind ProAccessManager.

import Foundation
import EventKit
import SwiftUI

struct MeetingPrepCard: Identifiable {
    let id = UUID()
    let eventTitle: String
    let startTime: Date
    let attendees: [String]
    let talkingPoints: [String]
    let questions: [String]
    let contextNote: String
    let generatedAt: Date = .now
}

@Observable @MainActor
final class MeetingPrepService {
    static let shared = MeetingPrepService()

    var prepCard: MeetingPrepCard? = nil
    var isGenerating: Bool = false

    private var lastCheckedEventID: String = ""

    private init() {}

    // MARK: - Check for upcoming meetings

    func checkAndGeneratePrep(events: [EKEvent]) async {
        guard ProAccessManager.shared.isPro else { return }
        guard !isGenerating else { return }

        let now = Date()
        let windowEnd = now.addingTimeInterval(35 * 60)  // 35-minute lookahead

        let upcoming = events.filter { event in
            guard let start = event.startDate, !event.isAllDay else { return false }
            return start > now && start <= windowEnd
        }.sorted { $0.startDate < $1.startDate }

        guard let next = upcoming.first else {
            // Clear stale card if meeting already started or none upcoming
            if let card = prepCard, card.startTime <= now {
                prepCard = nil
            }
            return
        }

        let eventID = next.eventIdentifier ?? next.title ?? ""
        guard eventID != lastCheckedEventID else { return }

        lastCheckedEventID = eventID
        await generatePrepCard(for: next)
    }

    // MARK: - Generate prep card via Claude

    private func generatePrepCard(for event: EKEvent) async {
        isGenerating = true
        defer { isGenerating = false }

        let title = event.title ?? "Meeting"
        let attendeeNames = (event.attendees ?? [])
            .compactMap { $0.name }
            .filter { !$0.isEmpty }
        let notes = event.notes ?? ""
        let startTime = event.startDate ?? Date()

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let prompt = """
        Generate a concise meeting prep card for this upcoming meeting.

        Meeting: \(title)
        Time: \(timeFormatter.string(from: startTime))
        Attendees: \(attendeeNames.isEmpty ? "Not specified" : attendeeNames.joined(separator: ", "))
        Notes/Agenda: \(notes.isEmpty ? "None provided" : notes)

        Respond with ONLY this JSON (no markdown, no explanation):
        {
          "talkingPoints": ["point 1", "point 2", "point 3"],
          "questions": ["question 1", "question 2"],
          "contextNote": "One sentence of helpful context or reminder."
        }
        """

        let messages: [LLMMessage] = [
            LLMMessage(role: .user, content: prompt)
        ]

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: messages,
                temperature: 0.4,
                maxTokens: 400
            )

            let jsonStr = extractJSON(from: raw)
            guard let data = jsonStr.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode(PrepResponse.self, from: data) else {
                // Fallback: minimal card
                prepCard = MeetingPrepCard(
                    eventTitle: title,
                    startTime: startTime,
                    attendees: attendeeNames,
                    talkingPoints: ["Review agenda", "Note key decisions", "Follow up on action items"],
                    questions: ["What's the main goal of this meeting?"],
                    contextNote: "Meeting in \(minutesUntil(startTime)) minutes."
                )
                return
            }

            prepCard = MeetingPrepCard(
                eventTitle: title,
                startTime: startTime,
                attendees: attendeeNames,
                talkingPoints: parsed.talkingPoints,
                questions: parsed.questions,
                contextNote: parsed.contextNote
            )
        } catch {
            // On error, don't show a card — fail silently
        }
    }

    private func minutesUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSinceNow / 60))
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }

    private struct PrepResponse: Decodable {
        let talkingPoints: [String]
        let questions: [String]
        let contextNote: String
    }
}
