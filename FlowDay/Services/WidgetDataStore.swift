// WidgetDataStore.swift
// FlowDay — Writes widget data to the App Group UserDefaults

import Foundation
import SwiftData
import WidgetKit

enum WidgetDataStore {

    // MARK: - Full Refresh (needs ModelContext)

    @MainActor
    static func refresh(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroup) else { return }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let tomorrow   = cal.date(byAdding: .day, value: 1, to: todayStart)!

        // Fetch all — no #Predicate, manual filter below
        let allTasks    = (try? context.fetch(FetchDescriptor<FDTask>())) ?? []
        let allSessions = (try? context.fetch(FetchDescriptor<FDFocusSession>())) ?? []
        let allEnergy   = (try? context.fetch(FetchDescriptor<FDEnergyLog>())) ?? []

        // Today's non-deleted tasks (scheduled or due today)
        let todayTasks = allTasks.filter { t in
            !t.isDeleted &&
            (t.isScheduledToday || (t.dueDate.map { cal.isDateInToday($0) } ?? false))
        }

        // Upcoming incomplete, sorted by time
        let upcoming = todayTasks
            .filter { !$0.isCompleted }
            .sorted {
                ($0.scheduledTime ?? $0.dueDate ?? .distantFuture) <
                ($1.scheduledTime ?? $1.dueDate ?? .distantFuture)
            }
            .prefix(5)
            .map { t in
                WidgetTask(
                    id: t.id,
                    title: t.title,
                    priorityRaw: t.priority.rawValue,
                    scheduledTime: t.scheduledTime,
                    dueDate: t.dueDate,
                    projectName: t.project?.name,
                    projectColorHex: t.project?.colorHex,
                    estimatedMinutes: t.estimatedMinutes
                )
            }

        // Today completed focus sessions
        let todaySessions = allSessions.filter { s in
            s.type == .focus && s.wasCompleted &&
            s.startedAt >= todayStart && s.startedAt < tomorrow
        }

        // Latest energy log today
        let todayEnergy = allEnergy
            .filter { cal.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
            .first

        let summary = WidgetSummary(
            totalTasks: todayTasks.count,
            completedTasks: todayTasks.filter(\.isCompleted).count,
            focusMinutesToday: todaySessions.reduce(0) { $0 + $1.durationMinutes },
            focusSessionsToday: todaySessions.count,
            focusScore: FocusScoreService.shared.todayScore,
            energyLevel: todayEnergy?.level.rawValue,
            upcomingTasks: Array(upcoming),
            updatedAt: .now
        )

        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: WidgetDataKeys.summary)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Focus State (no ModelContext needed)

    static func writeFocusState(_ state: WidgetFocusState) {
        guard let defaults = UserDefaults(suiteName: kWidgetAppGroup),
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: WidgetDataKeys.focusState)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearFocusState() {
        UserDefaults(suiteName: kWidgetAppGroup)?
            .removeObject(forKey: WidgetDataKeys.focusState)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
