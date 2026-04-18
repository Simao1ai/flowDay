// CalendarService.swift
// FlowDay
//
// Multi-provider calendar integration with two-way sync.
// This is Todoist's #1 user complaint — they only do one-way sync.
// FlowDay merges real calendar events into the daily timeline natively.
// Supports: Apple Calendar (EventKit), Google Calendar (REST API), Microsoft Outlook (Graph API).

import Foundation
import EventKit

@Observable
final class CalendarService {

    // @Observable doesn't support lazy, so we use a private backing + computed property
    private var _eventStore: EKEventStore?
    var eventStore: EKEventStore {
        if _eventStore == nil { _eventStore = EKEventStore() }
        return _eventStore!
    }

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var todayEvents: [EKEvent] = []

    /// Unified events from all providers (Apple + Google + Microsoft)
    var allTodayEvents: [UnifiedCalendarEvent] = []

    /// Reference to the account manager for multi-provider fetching
    var accountManager: CalendarAccountManager?

    init() {
        // Defer EventKit access — it can crash during early app startup
        DispatchQueue.main.async { [weak self] in
            self?.checkAuthorization()
        }
    }

    // MARK: - Authorization (Apple Calendar)

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

    // MARK: - Fetch Events (Apple Calendar — EventKit)

    /// Fetch all Apple calendar events for a given date
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }

        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }

    /// Convenience: fetch today's Apple events
    func fetchTodayEvents() {
        todayEvents = fetchEvents(for: .now)
    }

    // MARK: - Unified Multi-Provider Fetch

    /// Fetches events from ALL connected calendar providers for a given date
    func fetchAllEvents(for date: Date) async -> [UnifiedCalendarEvent] {
        var unified: [UnifiedCalendarEvent] = []

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        // 1. Apple Calendar (EventKit) — synchronous
        if authorizationStatus == .fullAccess {
            let appleEvents = fetchEvents(for: date)
            let mapped = appleEvents.compactMap { event -> UnifiedCalendarEvent? in
                guard let start = event.startDate, let end = event.endDate else { return nil }
                return UnifiedCalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    startDate: start,
                    endDate: end,
                    isAllDay: event.isAllDay,
                    provider: .apple,
                    calendarName: event.calendar?.title ?? "Apple Calendar"
                )
            }
            unified.append(contentsOf: mapped)
        }

        // 2. Google Calendar (REST API) — async
        if let manager = accountManager, manager.isConnected(.google) {
            let googleEvents = await manager.fetchGoogleCalendarEvents(
                startDate: startOfDay,
                endDate: endOfDay
            )
            let mapped = googleEvents.map { event in
                UnifiedCalendarEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    provider: .google,
                    calendarName: event.calendarName
                )
            }
            unified.append(contentsOf: mapped)
        }

        // 3. Microsoft Outlook (Graph API) — async
        if let manager = accountManager, manager.isConnected(.microsoft) {
            let msEvents = await manager.fetchMicrosoftCalendarEvents(
                startDate: startOfDay,
                endDate: endOfDay
            )
            let mapped = msEvents.map { event in
                UnifiedCalendarEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    provider: .microsoft,
                    calendarName: event.calendarName
                )
            }
            unified.append(contentsOf: mapped)
        }

        // Sort by start time
        unified.sort { $0.startDate < $1.startDate }

        return unified
    }

    /// Convenience: fetch all today's events from all providers
    func fetchAllTodayEvents() async {
        let events = await fetchAllEvents(for: .now)
        await MainActor.run {
            allTodayEvents = events
        }
    }

    // MARK: - Create Events (Two-way sync via Apple Calendar)

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

    // MARK: - Find Free Slots (for AI Scheduler — multi-provider)

    /// Returns available time slots between events for a given date (using ALL providers)
    func freeSlots(for date: Date, workdayStart: Int = 9, workdayEnd: Int = 18) -> [(start: Date, durationMinutes: Int)] {
        // Use Apple Calendar events (synchronous path — for backward compat)
        let events = fetchEvents(for: date)
        return computeFreeSlots(events: events, date: date, workdayStart: workdayStart, workdayEnd: workdayEnd)
    }

    /// Async version that checks ALL connected providers for free slots
    func freeSlotsAllProviders(for date: Date, workdayStart: Int = 9, workdayEnd: Int = 18) async -> [(start: Date, durationMinutes: Int)] {
        let allEvents = await fetchAllEvents(for: date)
        let cal = Calendar.current
        guard let dayStart = cal.date(bySettingHour: workdayStart, minute: 0, second: 0, of: date),
              let dayEnd = cal.date(bySettingHour: workdayEnd, minute: 0, second: 0, of: date)
        else { return [] }

        var slots: [(start: Date, durationMinutes: Int)] = []
        var cursor = dayStart

        for event in allEvents {
            guard !event.isAllDay else { continue }
            let eventStart = event.startDate
            let eventEnd = event.endDate
            guard eventStart >= dayStart && eventStart < dayEnd else { continue }

            if cursor < eventStart {
                let gap = Int(eventStart.timeIntervalSince(cursor) / 60)
                if gap >= 15 {
                    slots.append((start: cursor, durationMinutes: gap))
                }
            }
            cursor = max(cursor, eventEnd)
        }

        if cursor < dayEnd {
            let gap = Int(dayEnd.timeIntervalSince(cursor) / 60)
            if gap >= 15 {
                slots.append((start: cursor, durationMinutes: gap))
            }
        }

        return slots
    }

    /// Internal helper — compute free slots from Apple EKEvent array
    private func computeFreeSlots(events: [EKEvent], date: Date, workdayStart: Int, workdayEnd: Int) -> [(start: Date, durationMinutes: Int)] {
        let cal = Calendar.current
        guard let dayStart = cal.date(bySettingHour: workdayStart, minute: 0, second: 0, of: date),
              let dayEnd = cal.date(bySettingHour: workdayEnd, minute: 0, second: 0, of: date)
        else { return [] }

        var slots: [(start: Date, durationMinutes: Int)] = []
        var cursor = dayStart

        for event in events {
            guard let eventStart = event.startDate, let eventEnd = event.endDate else { continue }
            guard eventStart >= dayStart && eventStart < dayEnd else { continue }

            if cursor < eventStart {
                let gap = Int(eventStart.timeIntervalSince(cursor) / 60)
                if gap >= 15 {
                    slots.append((start: cursor, durationMinutes: gap))
                }
            }
            cursor = max(cursor, eventEnd)
        }

        if cursor < dayEnd {
            let gap = Int(dayEnd.timeIntervalSince(cursor) / 60)
            if gap >= 15 {
                slots.append((start: cursor, durationMinutes: gap))
            }
        }

        return slots
    }
}

// MARK: - Unified Calendar Event (used across all providers)

struct UnifiedCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let provider: CalendarProvider
    let calendarName: String

    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var providerIcon: String {
        provider.iconName
    }
}
