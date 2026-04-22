// WeekCalendarView.swift
// FlowDay — Wave 4b
//
// 7-day calendar grid with task chips. Swipe-navigable by week.

import SwiftUI

struct WeekCalendarView: View {
    let tasks: [FDTask]
    let taskService: TaskService?

    @State private var weekOffset: Int = 0
    @State private var selectedTask: FDTask?

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    // MARK: - Date helpers

    private var weekStart: Date {
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let start = cal.date(from: comps) ?? .now
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: start) ?? start
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRangeLabel: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            navigationHeader
            dayHeaderRow
            taskGrid
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task, taskService: taskService)
        }
    }

    // MARK: - Subviews

    private var navigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 30, height: 30)
                    .background(Color.fdAccentLight)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekRangeLabel)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                if weekOffset == 0 {
                    Text("This week")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdAccent)
                } else if weekOffset == 1 {
                    Text("Next week")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                } else if weekOffset == -1 {
                    Text("Last week")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 30, height: 30)
                    .background(Color.fdAccentLight)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var dayHeaderRow: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(weekDates, id: \.self) { date in
                dayHeader(date)
            }
        }
        .padding(.horizontal, 12)
    }

    private var taskGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(date)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Day components

    private func dayHeader(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let dayLetter = date.formatted(.dateTime.weekday(.narrow))
        let dayNum = date.formatted(.dateTime.day())

        return VStack(spacing: 3) {
            Text(dayLetter)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? Color.fdAccent : Color.fdTextMuted)

            ZStack {
                Circle()
                    .fill(isToday ? Color.fdAccent : Color.clear)
                    .frame(width: 22, height: 22)
                Text(dayNum)
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : Color.fdText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayCell(_ date: Date) -> some View {
        let dayTasks = tasks(for: date)
        let isToday = cal.isDateInToday(date)

        return VStack(spacing: 2) {
            ForEach(dayTasks.prefix(3)) { task in
                taskChip(task)
                    .onTapGesture { selectedTask = task }
            }
            if dayTasks.count > 3 {
                Text("+\(dayTasks.count - 3)")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.fdTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 56)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.fdAccentLight : Color.clear)
        )
    }

    private func taskChip(_ task: FDTask) -> some View {
        Text(task.title)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(task.priority.color.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Helpers

    private func tasks(for date: Date) -> [FDTask] {
        tasks.filter { task in
            guard let due = task.dueDate, !task.isDeleted, !task.isCompleted else { return false }
            return cal.isDate(due, inSameDayAs: date)
        }
    }
}
