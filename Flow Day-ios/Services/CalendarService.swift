// CalendarService.swift
// FlowDay
//
// EventKit integration for two-way calendar sync.
// This is Todoist's #1 user complaint — they only do one-way sync.
// FlowDay merges real calendar events into the daily timeline natively.

import Foundation
import EventKit

@Observable
final class CalendarService {

    let eventStore = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var todayEvents: [EKEvent] = []

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    fetchTodayEvents()
                }
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Fetch Events

    /// Fetch all calendar events for a given date
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }

        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }

    /// Convenience: fetch today's events
    func fetchTodayEvents() {
        todayEvents = fetchEvents(for: .now)
    }

    // MARK: - Create Events (Two-way sync)

    /// Create a calendar event from a FlowDay task (for time-blocked tasks)
    func createEvent(from task: FDTask) -> EKEvent? {
        guard authorizationStatus == .fullAccess,
              let startTime = task.scheduledTime else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = task.title
        event.startDate = startTime
        event.endDate = Calendar.current.date(
            byAdding: .minute,
            value: task.estimatedMinutes ?? 30,
            to: startTime
        )
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.notes = "Created by FlowDay"

        do {
            try eventStore.save(event, span: .thisEvent)
            return event
        } catch {
            print("Failed to create calendar event: \(error)")
            return nil
        }
    }

    // MARK: - Find Free Slots (for AI Scheduler)

    /// Returns available time slots between events for a given date
    func freeSlots(for date: Date, workdayStart: Int = 9, workdayEnd: Int = 18) -> [(start: Date, durationMinutes: Int)] {
        let events = fetchEvents(for: date)
        let cal = Calendar.current
        let dayStart = cal.date(bySettingHour: workdayStart, minute: 0, second: 0, of: date)!
        let dayEnd = cal.date(bySettingHour: workdayEnd, minute: 0, second: 0, of: date)!

        var slots: [(start: Date, durationMinutes: Int)] = []
        var cursor = dayStart

        for event in events {
            guard let eventStart = event.startDate, let eventEnd = event.endDate else { continue }
            guard eventStart >= dayStart && eventStart < dayEnd else { continue }

            // Gap between cursor and event start
            if cursor < eventStart {
                let gap = Int(eventStart.timeIntervalSince(cursor) / 60)
                if gap >= 15 { // Minimum 15-minute slot
                    slots.append((start: cursor, durationMinutes: gap))
                }
            }
            cursor = max(cursor, eventEnd)
        }

        // Gap after last event until end of workday
        if cursor < dayEnd {
            let gap = Int(dayEnd.timeIntervalSince(cursor) / 60)
            if gap >= 15 {
                slots.append((start: cursor, durationMinutes: gap))
            }
        }

        return slots
    }
}
