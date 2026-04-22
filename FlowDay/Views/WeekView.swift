// WeekView.swift
// FlowDay
// 7-column Mon–Sun week grid embedded in UpcomingView.
// Uses TabView with .page style for week swiping.
// No #Predicate — filtering is done in computed properties.

import SwiftUI
import SwiftData

// MARK: - Week view (embedded, no NavigationStack)

struct WeekView: View {
    let taskService: TaskService?
    @Binding var selectedTask: FDTask?

    @Query private var allTasksRaw: [FDTask]
    private var tasks: [FDTask] {
        allTasksRaw.filter { !$0.isDeleted && !$0.isCompleted }
    }

    @State private var weekOffset = 0

    var body: some View {
        TabView(selection: $weekOffset) {
            ForEach(Array(-26...26), id: \.self) { offset in
                WeekPageView(tasks: tasks, weekOffset: offset, selectedTask: $selectedTask)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.fdBackground)
    }
}

// MARK: - Single week page

struct WeekPageView: View {
    let tasks: [FDTask]
    let weekOffset: Int
    @Binding var selectedTask: FDTask?

    private var weekDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        // 1=Sun…7=Sat → daysFromMonday: Sun=6, Mon=0, Tue=1, …
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let monday = cal.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    private var weekRangeLabel: String {
        if weekOffset == 0 { return "This Week" }
        if weekOffset == 1 { return "Next Week" }
        if weekOffset == -1 { return "Last Week" }
        guard let start = weekDays.first, let end = weekDays.last else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func dayTasks(for day: Date) -> [FDTask] {
        let cal = Calendar.current
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(weekRangeLabel)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

            // Day column headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    WeekDayHeader(date: day)
                }
            }
            .padding(.horizontal, 6)

            Divider().padding(.horizontal, 6)

            // Task columns
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        WeekDayColumn(
                            date: day,
                            tasks: dayTasks(for: day),
                            selectedTask: $selectedTask
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .background(Color.fdBackground)
    }
}

// MARK: - Day header cell

struct WeekDayHeader: View {
    let date: Date
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.narrow)))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? Color.fdAccent : Color.fdTextMuted)
                .textCase(.uppercase)

            ZStack {
                Circle()
                    .fill(isToday ? Color.fdAccent : Color.clear)
                    .frame(width: 24, height: 24)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : Color.fdText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Day column of task chips

struct WeekDayColumn: View {
    let date: Date
    let tasks: [FDTask]
    @Binding var selectedTask: FDTask?

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(tasks) { task in
                Button { selectedTask = task } label: {
                    Text(task.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(task.priority.color.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
        .padding(.horizontal, 1.5)
        .background(isToday ? Color.fdAccent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
