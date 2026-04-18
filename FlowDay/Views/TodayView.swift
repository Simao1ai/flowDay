// TodayView.swift
// FlowDay
//
// THE core screen — the unified daily timeline.
// Tasks, calendar events, and habits merged into one chronological view.
// This is what Todoist cannot do and the #1 reason users will switch.

import SwiftUI
import SwiftData
import EventKit

struct TodayView: View {
    let taskService: TaskService?
    let calendarService: CalendarService

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// Falls back to a locally-created TaskService when RootView hasn't
    /// set one yet (i.e. before onAppear fires).
    private var resolvedTaskService: TaskService {
        taskService ?? TaskService(modelContext: modelContext)
    }

    // Plain @Query — predicates and sorts crash on iOS 26.x beta.
    // Filtering is done in computed properties instead.
    @Query private var allTasksRaw: [FDTask]

    private var allTasks: [FDTask] {
        allTasksRaw.filter { !$0.isDeleted }
    }

    @Query
    private var allHabits: [FDHabit]

    private var habits: [FDHabit] {
        allHabits.filter { $0.isActive }
    }

    @State private var showQuickAdd = false
    @State private var showSettings = false
    @State private var showAIPlan = false
    @State private var expandedTaskID: UUID?
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool

    private var todayTasks: [FDTask] {
        allTasks.filter { $0.isScheduledToday }
    }

    private var unscheduledTasks: [FDTask] {
        allTasks.filter { !$0.isDeleted && !$0.isCompleted && $0.scheduledTime == nil && $0.dueDate == nil }
    }

    private var completedToday: Int {
        todayTasks.filter(\.isCompleted).count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Header stats
                        headerSection

                        // AI Banner
                        aiBannerSection

                        // Habits row
                        if !habits.isEmpty {
                            habitsSection
                        }

                        // Unified Timeline
                        timelineSection

                        // Unscheduled tasks
                        if !unscheduledTasks.isEmpty {
                            unscheduledSection
                        }

                        Spacer(minLength: 100) // Room for quick-add bar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .background(Color.fdBackground)

                // Quick Add bar (always visible at bottom)
                quickAddBar
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if let energy = appState.todayEnergy {
                            energyBadge(energy)
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAIPlan) {
                AIPlanView(taskService: resolvedTaskService, energyLevel: appState.todayEnergy)
            }
        }
    }

    // MARK: - Header Stats

    private var headerSection: some View {
        HStack(spacing: 12) {
            StatCard(
                label: "Tasks",
                value: "\(completedToday)/\(todayTasks.count)",
                icon: "checkmark.circle",
                color: .fdGreen
            )
            StatCard(
                label: "Habits",
                value: "\(habits.filter(\.isCompletedToday).count)/\(habits.filter(\.isDueToday).count)",
                icon: "flame",
                color: .fdAccent
            )
            StatCard(
                label: "Events",
                value: "\(calendarService.todayEvents.count)",
                icon: "calendar",
                color: .fdBlue
            )
        }
    }

    // MARK: - AI Banner

    private var aiBannerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("FlowDay AI")
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                Text("Ready to optimize your schedule based on your energy and calendar.")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                showAIPlan = true
            } label: {
                Text("Plan")
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.fdAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.fdAccentLight, Color.fdPurpleLight],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 11))
                Text("Daily Habits")
            }
            .fdSectionHeader()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(habits.filter(\.isDueToday)) { habit in
                        HabitCardView(habit: habit)
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("Daily Timeline")
            }
            .fdSectionHeader()

            let timeline = TimelineBuilder.buildTimeline(
                tasks: todayTasks,
                events: calendarService.todayEvents,
                habits: habits.filter(\.isDueToday),
                for: .now
            )

            if timeline.isEmpty {
                emptyTimelineView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(timeline) { item in
                        timelineItemView(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineItemView(_ item: TimelineItem) -> some View {
        switch item {
        case .task(let task):
            TaskRowView(
                task: task,
                isExpanded: expandedTaskID == task.id,
                onToggle: { resolvedTaskService.toggleComplete(task) },
                onToggleSubtask: { sub in resolvedTaskService.toggleSubtaskComplete(sub) },
                onExpand: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedTaskID = expandedTaskID == task.id ? nil : task.id
                    }
                }
            )
        case .calendarEvent(let event):
            CalendarEventRow(event: event)
        case .habit(let habit):
            HabitTimelineRow(habit: habit)
        }
    }

    private var emptyTimelineView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max")
                .font(.system(size: 32))
                .foregroundStyle(Color.fdTextMuted.opacity(0.5))
            Text("Nothing scheduled yet")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
            Text("Add a task or tap \"Plan\" to let AI build your day")
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Unscheduled

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 11))
                Text("Unscheduled")
            }
            .fdSectionHeader()

            LazyVStack(spacing: 8) {
                ForEach(unscheduledTasks) { task in
                    TaskRowView(
                        task: task,
                        isExpanded: expandedTaskID == task.id,
                        onToggle: { resolvedTaskService.toggleComplete(task) },
                        onToggleSubtask: { sub in resolvedTaskService.toggleSubtaskComplete(sub) },
                        onExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedTaskID = expandedTaskID == task.id ? nil : task.id
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Quick Add

    private var quickAddBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.fdBackground.opacity(0), Color.fdBackground],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 20)

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)

                TextField("Add a task...", text: $quickAddText)
                    .font(.fdBody)
                    .focused($quickAddFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !quickAddText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        resolvedTaskService.createTask(title: quickAddText)
                        quickAddText = ""
                    }

                Button {
                    // Voice capture — Phase 2
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.fdAccent.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 12, y: -2)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Energy Badge

    private func energyBadge(_ level: EnergyLevel) -> some View {
        HStack(spacing: 5) {
            Text(level.emoji)
                .font(.caption)
            Text(level.label)
                .font(.fdMicro)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(energyColor(level).opacity(0.12))
        .clipShape(Capsule())
        .foregroundStyle(energyColor(level))
    }

    private func energyColor(_ level: EnergyLevel) -> Color {
        switch level {
        case .high:   .fdAccent
        case .normal: .fdYellow
        case .low:    .fdBlue
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(value)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
            }
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: FDTask
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToggleSubtask: (FDSubtask) -> Void
    let onExpand: () -> Void

    private var priorityColor: Color {
        Color(task.priority.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(task.isCompleted ? Color.fdGreen : priorityColor.opacity(0.5), lineWidth: 2)
                        .fill(task.isCompleted ? Color.fdGreen : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay {
                            if task.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.fdBody)
                        .foregroundStyle(task.isCompleted ? Color.fdTextMuted : Color.fdText)
                        .strikethrough(task.isCompleted)

                    HStack(spacing: 8) {
                        // Priority badge
                        Text(task.priority.label)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.12))
                            .foregroundStyle(priorityColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        // Project
                        if let project = task.project {
                            Text(project.name)
                                .font(.fdMicro)
                                .foregroundStyle(Color(hex: project.colorHex))
                        }

                        // Time
                        if let time = task.scheduledTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(time.formatted(.dateTime.hour().minute()))
                            }
                            .font(.fdMono)
                            .foregroundStyle(Color.fdTextMuted)
                        }

                        // Duration
                        if let mins = task.estimatedMinutes {
                            Text("\(mins)m")
                                .font(.fdMono)
                                .foregroundStyle(Color.fdTextMuted)
                        }

                        // Subtask count
                        if !task.subtasks.isEmpty {
                            Button(action: onExpand) {
                                HStack(spacing: 3) {
                                    Text("\(task.subtasks.filter(\.isCompleted).count)/\(task.subtasks.count)")
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8))
                                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                }
                                .font(.fdMono)
                                .foregroundStyle(Color.fdTextMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)

            // Expanded subtasks
            if isExpanded && !task.subtasks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(task.subtasks.sorted(by: { $0.sortOrder < $1.sortOrder })) { subtask in
                        HStack(spacing: 10) {
                            Button { onToggleSubtask(subtask) } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(subtask.isCompleted ? Color.fdGreen : Color.fdBorder, lineWidth: 1.5)
                                    .fill(subtask.isCompleted ? Color.fdGreen : Color.clear)
                                    .frame(width: 15, height: 15)
                                    .overlay {
                                        if subtask.isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .font(.fdCaption)
                                .foregroundStyle(subtask.isCompleted ? Color.fdTextMuted : Color.fdTextSecondary)
                                .strikethrough(subtask.isCompleted)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.leading, 46)
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(Color.fdBlue)

            Text(event.title ?? "Event")
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            if let start = event.startDate {
                Text(start.formatted(.dateTime.hour().minute()))
                    .font(.fdMono)
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
        .padding(14)
        .background(Color.fdBlue.opacity(0.06))
        .overlay(
            Rectangle()
                .fill(Color.fdBlue)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Habit Card

struct HabitCardView: View {
    let habit: FDHabit
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            let _ = habit.toggleToday()
            try? modelContext.save()
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Text(habit.emoji)
                        .font(.title2)
                    if habit.isCompletedToday {
                        Circle()
                            .fill(Color(hex: habit.colorHex))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 6, y: -4)
                    }
                }
                Text(habit.name)
                    .font(.fdMicro)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(habit.currentStreak)d")
                        .font(.fdMicroBold)
                }
                .foregroundStyle(Color(hex: habit.colorHex))
            }
            .frame(width: 88)
            .padding(.vertical, 14)
            .background(
                habit.isCompletedToday
                    ? Color(hex: habit.colorHex).opacity(0.08)
                    : Color.fdSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        habit.isCompletedToday
                            ? Color(hex: habit.colorHex).opacity(0.3)
                            : Color.fdBorderLight,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Habit Timeline Row

struct HabitTimelineRow: View {
    let habit: FDHabit

    var body: some View {
        HStack(spacing: 12) {
            Text(habit.emoji)
                .font(.callout)
            Text(habit.name)
                .font(.fdBody)
                .foregroundStyle(habit.isCompletedToday ? Color.fdTextMuted : Color.fdText)
                .strikethrough(habit.isCompletedToday)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                Text("\(habit.currentStreak)")
                    .font(.fdMono)
            }
            .foregroundStyle(Color(hex: habit.colorHex))
        }
        .padding(14)
        .background(Color(hex: habit.colorHex).opacity(0.05))
        .overlay(
            Rectangle()
                .fill(Color(hex: habit.colorHex))
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
