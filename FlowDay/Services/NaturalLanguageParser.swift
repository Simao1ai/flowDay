// NaturalLanguageParser.swift
// FlowDay
//
// Todoist's killer feature: type "Review contract from Sarah by Friday 13:00 p2"
// and it auto-parses date, time, priority, project.
// FlowDay does it BETTER — also parses duration, energy, labels.

import Foundation
import SwiftData

struct ParsedTask {
    var title: String
    var dueDate: Date?
    var scheduledTime: Date?
    var priority: TaskPriority
    var projectName: String?
    var labels: [String]
    var estimatedMinutes: Int?
    var recurrenceRule: String?

    // For display — which tokens were parsed
    var parsedTokens: [ParsedToken]
}

struct ParsedToken: Identifiable {
    let id = UUID()
    let text: String
    let type: TokenType
    let range: Range<String.Index>

    enum TokenType {
        case date
        case time
        case priority
        case project
        case label
        case duration
        case recurrence
    }
}

final class NaturalLanguageParser {

    private let calendar = Calendar.current

    func parse(_ input: String) -> ParsedTask {
        var remaining = input
        var tokens: [ParsedToken] = []

        let priority = extractPriority(from: &remaining, tokens: &tokens)
        let projectName = extractProject(from: &remaining, tokens: &tokens)
        let labels = extractLabels(from: &remaining, tokens: &tokens)
        let duration = extractDuration(from: &remaining, tokens: &tokens)
        let recurrence = extractRecurrence(from: &remaining, tokens: &tokens)
        let (dueDate, scheduledTime) = extractDateTime(from: &remaining, tokens: &tokens)

        let title = remaining
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return ParsedTask(
            title: title,
            dueDate: dueDate,
            scheduledTime: scheduledTime,
            priority: priority,
            projectName: projectName,
            labels: labels,
            estimatedMinutes: duration,
            recurrenceRule: recurrence,
            parsedTokens: tokens
        )
    }

    // MARK: - Priority (p1, p2, p3, p4)

    private func extractPriority(from text: inout String, tokens: inout [ParsedToken]) -> TaskPriority {
        let patterns: [(String, TaskPriority)] = [
            ("\\bp1\\b", .urgent),
            ("\\bp2\\b", .high),
            ("\\bp3\\b", .medium),
            ("\\bp4\\b", .none),
            ("\\b!1\\b", .urgent),
            ("\\b!2\\b", .high),
            ("\\b!3\\b", .medium),
        ]

        for (pattern, priority) in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[range])
                tokens.append(ParsedToken(text: matched, type: .priority, range: range))
                text.removeSubrange(range)
                return priority
            }
        }
        return .none
    }

    // MARK: - Project (#ProjectName or +ProjectName)

    private func extractProject(from text: inout String, tokens: inout [ParsedToken]) -> String? {
        // Match #ProjectName or #"Project Name"
        if let range = text.range(of: "#\"[^\"]+\"", options: .regularExpression) {
            let matched = String(text[range])
            let name = matched.dropFirst(2).dropLast(1)
            tokens.append(ParsedToken(text: matched, type: .project, range: range))
            text.removeSubrange(range)
            return String(name)
        }

        if let range = text.range(of: "#\\w+", options: .regularExpression) {
            let matched = String(text[range])
            let name = String(matched.dropFirst())
            tokens.append(ParsedToken(text: matched, type: .project, range: range))
            text.removeSubrange(range)
            return name
        }

        return nil
    }

    // MARK: - Labels (@label)

    private func extractLabels(from text: inout String, tokens: inout [ParsedToken]) -> [String] {
        var labels: [String] = []
        while let range = text.range(of: "@\\w+", options: .regularExpression) {
            let matched = String(text[range])
            let label = String(matched.dropFirst())
            tokens.append(ParsedToken(text: matched, type: .label, range: range))
            text.removeSubrange(range)
            labels.append(label)
        }
        return labels
    }

    // MARK: - Duration (30m, 1h, 1.5h, 45min, 2hr)

    private func extractDuration(from text: inout String, tokens: inout [ParsedToken]) -> Int? {
        // Match patterns like "30m", "1h", "1.5h", "45min", "2hr", "90 min"
        let pattern = "\\b(\\d+\\.?\\d*)\\s*(m|min|mins|minutes|h|hr|hrs|hours)\\b"
        if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let matched = String(text[range])
            tokens.append(ParsedToken(text: matched, type: .duration, range: range))
            text.removeSubrange(range)

            // Parse the number and unit
            let numPattern = "(\\d+\\.?\\d*)"
            if let numRange = matched.range(of: numPattern, options: .regularExpression) {
                let numStr = String(matched[numRange])
                let value = Double(numStr) ?? 0
                if matched.lowercased().contains("h") {
                    return Int(value * 60)
                } else {
                    return Int(value)
                }
            }
        }
        return nil
    }

    // MARK: - Recurrence (every day, every Monday, daily, weekly)

    private func extractRecurrence(from text: inout String, tokens: inout [ParsedToken]) -> String? {
        let patterns: [(String, String)] = [
            ("\\bevery\\s+day\\b", "RRULE:FREQ=DAILY"),
            ("\\bdaily\\b", "RRULE:FREQ=DAILY"),
            ("\\bevery\\s+week\\b", "RRULE:FREQ=WEEKLY"),
            ("\\bweekly\\b", "RRULE:FREQ=WEEKLY"),
            ("\\bevery\\s+month\\b", "RRULE:FREQ=MONTHLY"),
            ("\\bmonthly\\b", "RRULE:FREQ=MONTHLY"),
            ("\\bevery\\s+monday\\b", "RRULE:FREQ=WEEKLY;BYDAY=MO"),
            ("\\bevery\\s+tuesday\\b", "RRULE:FREQ=WEEKLY;BYDAY=TU"),
            ("\\bevery\\s+wednesday\\b", "RRULE:FREQ=WEEKLY;BYDAY=WE"),
            ("\\bevery\\s+thursday\\b", "RRULE:FREQ=WEEKLY;BYDAY=TH"),
            ("\\bevery\\s+friday\\b", "RRULE:FREQ=WEEKLY;BYDAY=FR"),
            ("\\bevery\\s+saturday\\b", "RRULE:FREQ=WEEKLY;BYDAY=SA"),
            ("\\bevery\\s+sunday\\b", "RRULE:FREQ=WEEKLY;BYDAY=SU"),
            ("\\bevery\\s+weekday\\b", "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"),
        ]

        for (pattern, rule) in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[range])
                tokens.append(ParsedToken(text: matched, type: .recurrence, range: range))
                text.removeSubrange(range)
                return rule
            }
        }
        return nil
    }

    // MARK: - Date & Time

    private func extractDateTime(from text: inout String, tokens: inout [ParsedToken]) -> (Date?, Date?) {
        var dueDate: Date?
        var scheduledTime: Date?

        // Try "by" prefix for due dates: "by Friday", "by Dec 25"
        // Try "at" prefix for scheduled time: "at 2pm", "at 14:00"

        // Extract explicit time first: "13:00", "2pm", "at 3:30pm"
        scheduledTime = extractTime(from: &text, tokens: &tokens)

        // Extract date
        dueDate = extractDate(from: &text, tokens: &tokens)

        // If we got a time but no date, assume today
        if scheduledTime != nil && dueDate == nil {
            dueDate = calendar.startOfDay(for: .now)
        }

        // Merge date and time if both present
        if let date = dueDate, let time = scheduledTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            scheduledTime = calendar.date(from: dateComponents)
        }

        return (dueDate, scheduledTime)
    }

    private func extractTime(from text: inout String, tokens: inout [ParsedToken]) -> Date? {
        // Match "13:00", "1:30pm", "2pm", "at 14:00", "at 2pm"
        let patterns = [
            "\\b(?:at\\s+)?(\\d{1,2}):(\\d{2})\\s*(am|pm)?\\b",
            "\\b(?:at\\s+)?(\\d{1,2})\\s*(am|pm)\\b",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
            else { continue }

            let fullRange = Range(match.range, in: text)!
            let matched = String(text[fullRange])
            tokens.append(ParsedToken(text: matched, type: .time, range: fullRange))

            // Parse hour
            var hour = 0
            var minute = 0

            if match.numberOfRanges > 1, let r1 = Range(match.range(at: 1), in: text) {
                hour = Int(text[r1]) ?? 0
            }
            if match.numberOfRanges > 2, let r2 = Range(match.range(at: 2), in: text) {
                let val = String(text[r2])
                if val.count <= 2 && Int(val) != nil {
                    minute = Int(val) ?? 0
                }
            }

            // Check for am/pm
            let lower = matched.lowercased()
            if lower.contains("pm") && hour < 12 {
                hour += 12
            } else if lower.contains("am") && hour == 12 {
                hour = 0
            }

            text.removeSubrange(fullRange)

            var comps = calendar.dateComponents([.year, .month, .day], from: .now)
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps)
        }

        return nil
    }

    private func extractDate(from text: inout String, tokens: inout [ParsedToken]) -> Date? {
        let today = Date.now

        // Relative dates
        let relativeDates: [(String, () -> Date?)] = [
            ("\\b(?:by\\s+)?today\\b", { today }),
            ("\\b(?:by\\s+)?tomorrow\\b", { self.calendar.date(byAdding: .day, value: 1, to: today) }),
            ("\\b(?:by\\s+)?day after tomorrow\\b", { self.calendar.date(byAdding: .day, value: 2, to: today) }),
            ("\\bnext\\s+week\\b", { self.calendar.date(byAdding: .weekOfYear, value: 1, to: today) }),
            ("\\bnext\\s+month\\b", { self.calendar.date(byAdding: .month, value: 1, to: today) }),
        ]

        for (pattern, dateFunc) in relativeDates {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[range])
                tokens.append(ParsedToken(text: matched, type: .date, range: range))
                text.removeSubrange(range)
                return dateFunc()
            }
        }

        // Day names: "Monday", "by Friday", "next Tuesday"
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in days.enumerated() {
            let pattern = "\\b(?:by\\s+|next\\s+)?\(day)\\b"
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[range])
                tokens.append(ParsedToken(text: matched, type: .date, range: range))
                text.removeSubrange(range)
                return nextDate(forWeekday: index + 1)
            }
        }

        // Explicit dates: "Dec 25", "Jan 3", "12/25"
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        for (index, month) in months.enumerated() {
            let pattern = "\\b(?:by\\s+)?\(month)(?:uary|ruary|ch|il|e|ust|ember|ober|tember)?\\s+(\\d{1,2})\\b"
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[range])

                // Extract day number
                if let dayRange = matched.range(of: "\\d{1,2}", options: .regularExpression, range: matched.index(matched.startIndex, offsetBy: 3)..<matched.endIndex) {
                    let dayNum = Int(matched[dayRange]) ?? 1
                    tokens.append(ParsedToken(text: matched, type: .date, range: range))
                    text.removeSubrange(range)

                    var comps = DateComponents()
                    comps.month = index + 1
                    comps.day = dayNum
                    comps.year = calendar.component(.year, from: today)
                    if let date = calendar.date(from: comps), date < today {
                        comps.year = calendar.component(.year, from: today) + 1
                    }
                    return calendar.date(from: comps)
                }
            }
        }

        return nil
    }

    private func nextDate(forWeekday target: Int) -> Date {
        let today = Date.now
        let current = calendar.component(.weekday, from: today)
        var daysToAdd = target - current
        if daysToAdd <= 0 { daysToAdd += 7 }
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}
