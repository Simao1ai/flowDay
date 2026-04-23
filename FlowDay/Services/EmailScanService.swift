// EmailScanService.swift
// FlowDay — Scans fetched emails and surfaces actionable task suggestions via AI

import Foundation

// MARK: - Email Task Suggestion

struct EmailTaskSuggestion: Identifiable {
    let id = UUID()
    let emailId: String
    let emailFrom: String
    let emailSubject: String
    let suggestedTitle: String
    let suggestedPriority: TaskPriority
    let suggestedDueDate: Date?
    let suggestedNotes: String
}

// MARK: - Email Scan Service

final class EmailScanService {

    static let shared = EmailScanService()
    private init() {}

    /// Analyses an array of EmailMessages and returns actionable task suggestions.
    /// Sends the email list to the Supabase Edge Function (feature: emailToTask) and
    /// parses the JSON array response.
    func scan(emails: [EmailMessage]) async -> [EmailTaskSuggestion] {
        guard !emails.isEmpty else { return [] }

        let emailBlock = emails.enumerated().map { index, msg in
            """
            [\(index + 1)] id=\(msg.id)
            From: \(msg.from)
            Subject: \(msg.subject)
            Date: \(msg.date.formatted(.dateTime.month().day().year()))
            Preview: \(msg.snippet)
            """
        }.joined(separator: "\n\n")

        let prompt = """
        You are an AI assistant that identifies emails requiring the recipient to take action.

        Analyse the emails below. For each one that clearly requires the recipient to do something \
        (reply, complete a task, attend something, send information, etc.) return a JSON object.

        Return a JSON array only — no prose, no markdown fences. If no emails need action return [].

        Each item must be:
        {"emailId":"<id from the listing>","title":"<concise action task title>","priority":<1-4>,"dueDate":"YYYY-MM-DD or null","notes":"<one sentence of context>"}

        Priority: 1=urgent, 2=high, 3=medium, 4=none (only use 1-2 if genuinely time-sensitive).

        Emails:
        \(emailBlock)
        """

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .emailToTask,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.2,
                maxTokens: 1024
            )

            return parse(response: raw, emails: emails)
        } catch {
            return []
        }
    }

    // MARK: - Response Parsing

    private func parse(response raw: String, emails: [EmailMessage]) -> [EmailTaskSuggestion] {
        // Strip optional code fences and find the JSON array boundaries
        let stripped = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = stripped.range(of: "["),
              let end   = stripped.range(of: "]", options: .backwards) else { return [] }

        let jsonString = String(stripped[start.lowerBound...end.upperBound])

        guard let data  = jsonString.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let emailMap = Dictionary(uniqueKeysWithValues: emails.map { ($0.id, $0) })

        return items.compactMap { item -> EmailTaskSuggestion? in
            guard let emailId = item["emailId"] as? String,
                  let title   = item["title"] as? String,
                  let email   = emailMap[emailId] else { return nil }

            let priorityRaw = item["priority"] as? Int ?? 4
            let priority: TaskPriority
            switch priorityRaw {
            case 1: priority = .urgent
            case 2: priority = .high
            case 3: priority = .medium
            default: priority = .none
            }

            var dueDate: Date? = nil
            if let dateStr = item["dueDate"] as? String,
               dateStr != "null", !dateStr.isEmpty {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                dueDate = f.date(from: dateStr)
            }

            let notes = item["notes"] as? String ?? ""

            return EmailTaskSuggestion(
                emailId: emailId,
                emailFrom: email.from,
                emailSubject: email.subject,
                suggestedTitle: title,
                suggestedPriority: priority,
                suggestedDueDate: dueDate,
                suggestedNotes: notes
            )
        }
    }
}
