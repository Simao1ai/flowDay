// WeekView.swift
// FlowDay

import SwiftUI

struct WeekView: View {
    let tasks: [FDTask]
    let onTaskTap: (FDTask) -> Void

    @State private var weekOffset: Int = 0
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private let cal = Calendar.current

    // Sunday-anchored week start
    private var weekStart: Date {
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today) // 1=Sun … 7=Sat
        let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: sunday)!
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    private func tasksForDay(_ day: Date) -> [FDTask] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    private var selectedDayTasks: [FDTask] {
        tasksForDay(selectedDay)
            .sorted { ($0.scheduledTime ?? $0.dueDate ?? .distantFuture) < ($1.scheduledTime ?? $1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            dayGrid
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            Divider()
            selectedDayList
        }
        // Horizontal drag on the grid row navigates weeks; vertical drag stays for the scroll view
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { val in
                    guard abs(val.translation.width) > abs(val.translation.height) * 1.5 else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        weekOffset += val.translation.width < 0 ? 1 : -1
                    }
                }
        )
    }

    // MARK: - Week navigation header

    private var navigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 36, height: 36)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 7-column day grid

    private var dayGrid: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = cal.isDateInToday(day)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let dayTasks = tasksForDay(day)

        return Button {
            withAnimation(.easeInOut(duration: 0.12)) { selectedDay = day }
        } label: {
            VStack(spacing: 4) {
                // Day abbreviation
                Text(dayAbbr(day))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isToday ? Color.fdAccent : Color.fdTextMuted)

                // Day number
                Text(dayNum(day))
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : (isSelected ? Color.fdAccent : Color.fdText))
                    .frame(width: 28, height: 28)
                    .background(isToday ? Color.fdAccent : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected && !isToday ? Color.fdAccent : Color.clear, lineWidth: 1.5)
                    )

                // Task dot indicators (up to 3 colored dots)
                HStack(spacing: 2) {
                    ForEach(dayTasks.prefix(3)) { t in
                        Circle()
                            .fill(t.priority.color)
                            .frame(width: 5, height: 5)
                    }
                    if dayTasks.count > 3 {
                        Circle()
                            .fill(Color.fdTextMuted)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 8)

                if !dayTasks.isEmpty {
                    Text("\(dayTasks.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.fdTextMuted)
                } else {
                    // Keep height consistent
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.fdAccent.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected day task list

    private var selectedDayList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Date header
                HStack(spacing: 6) {
                    Text(selectedDayFullLabel)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Spacer()
                    Text("\(selectedDayTasks.count) task\(selectedDayTasks.count == 1 ? "" : "s")")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                if selectedDayTasks.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.fdAccent.opacity(0.3))
                        Text("No tasks for this day")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(selectedDayTasks) { task in
                            weekTaskRow(task)
                                .onTapGesture { onTaskTap(task) }
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func weekTaskRow(_ task: FDTask) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .stroke(task.priority.color.opacity(0.5), lineWidth: 2)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                if let time = task.scheduledTime {
                    Text(time.formatted(.dateTime.hour().minute()))
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }

            Spacer()

            if let project = task.project {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var selectedDayFullLabel: String {
        if cal.isDateInToday(selectedDay) { return "Today" }
        if cal.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if cal.isDateInYesterday(selectedDay) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: selectedDay)
    }

    private func dayAbbr(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private func dayNum(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }
}
