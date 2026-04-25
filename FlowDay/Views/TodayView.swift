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
    @Environment(EmailAccountService.self) private var emailAccountService
    @Environment(FocusTimerService.self) private var timerService
    @Environment(\.modelContext) private var modelContext

    private var proAccess: ProAccessManager { .shared }

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

    @Query
    private var allFocusSessions: [FDFocusSession]

    @State private var showQuickAdd = false
    @State private var showSettings = false
    @State private var showAIPlan = false
    @State private var showAutoSchedule = false
    @State private var showWeeklyReport = false
    @State private var showRamble = false

    private var scoreService: FocusScoreService { .shared }
    @State private var showDayRecap = false
    @State private var showFocusTimer = false
    @State private var focusTimerPrelinkedTask: UUID? = nil
    @State private var showEmailTasks = false
    @State private var showProUpgrade = false
    @State private var proUpgradeFeature: ProFeature = .unlimitedAI
    @State private var emailSuggestions: [EmailTaskSuggestion] = []
    @State private var hasScannedEmails = false
    @State private var isScanningEmails = false
    @State private var expandedTaskID: UUID?
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool
    @State private var selection = SelectionState()
    @State private var planButtonShimmer = false
    @State private var taskSwipeOffsets: [UUID: CGFloat] = [:]

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
                VStack(spacing: 0) {
                    SelectionHeader(selection: selection)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {

                            // Header stats
                            headerSection

                            // AI Banner
                            aiBannerSection

                            // Email Tasks card — Pro feature
                            if !emailSuggestions.isEmpty && proAccess.isFeatureAvailable(.emailToTask) {
                                emailTasksCard
                            }

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
                }
                .background(Color.fdBackground)

                // Bottom-anchored: batch action bar (when selecting) or quick-add bar
                if selection.isActive {
                    BatchActionBar(
                        selection: selection,
                        taskService: resolvedTaskService,
                        allTasks: allTasks
                    )
                } else {
                    quickAddBar
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                triggerEmailScan()
                scoreService.calculateDailyScore(
                    tasks: allTasks,
                    focusSessions: allFocusSessions,
                    habits: allHabits,
                    energy: appState.todayEnergy
                )
            }
            .onChange(of: completedToday) { _, _ in
                scoreService.calculateDailyScore(
                    tasks: allTasks,
                    focusSessions: allFocusSessions,
                    habits: allHabits,
                    energy: appState.todayEnergy
                )
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        if let energy = appState.todayEnergy {
                            energyBadge(energy)
                        }
                        SyncStatusBadge()
                        Button {
                            showFocusTimer = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "timer")
                                    .font(.system(size: 16))
                                    .foregroundStyle(timerService.phase == .idle ? Color.fdTextSecondary : Color.fdAccent)
                                if timerService.phase != .idle {
                                    Circle()
                                        .fill(Color.fdAccent)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                        Button {
                            showDayRecap = true
                        } label: {
                            Image(systemName: "moon.stars")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.fdTextSecondary)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.fdBackground)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEmailTasks) {
                EmailTasksView(suggestions: $emailSuggestions)
            }
            .sheet(isPresented: $showAIPlan) {
                AIPlanView(taskService: resolvedTaskService, energyLevel: appState.todayEnergy)
            }
            .sheet(isPresented: $showAutoSchedule) {
                AutoScheduleView(
                    taskService: resolvedTaskService,
                    calendarService: calendarService,
                    energyLevel: appState.todayEnergy
                )
            }
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
                    .environment(appState)
            }
            .fullScreenCover(isPresented: $showRamble) {
                RambleView(taskService: resolvedTaskService)
                    .environment(appState)
            }
            .sheet(isPresented: $showDayRecap) {
                DayRecapView()
                    .environment(appState)
            }
            .sheet(isPresented: $showFocusTimer) {
                FocusTimerView(prelinkedTaskID: focusTimerPrelinkedTask)
                    .environment(timerService)
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView(highlightedFeature: proUpgradeFeature)
            }
        }
    }

    private func requirePro(_ feature: ProFeature, then action: () -> Void) {
        if proAccess.isFeatureAvailable(feature) {
            action()
        } else {
            proUpgradeFeature = feature
            showProUpgrade = true
            Haptics.warning()
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
            FocusScoreView(scoreService: scoreService, showWeeklyReport: $showWeeklyReport)
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
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
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
                showAutoSchedule = true
            } label: {
                Text("Plan")
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.fdAccent)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 36)
                        .offset(x: planButtonShimmer ? 60 : -60)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.fdAccent.opacity(0.13), Color.fdPurple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false).delay(0.8)) {
                planButtonShimmer = true
            }
        }
    }

    // MARK: - Email Tasks Card

    private var emailTasksCard: some View {
        Button { showEmailTasks = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "EA4335"))
                        .frame(width: 40, height: 40)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Email Tasks")
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdText)
                    Text("\(emailSuggestions.count) email\(emailSuggestions.count == 1 ? "" : "s") need\(emailSuggestions.count == 1 ? "s" : "") your attention")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextSecondary)
                }

                Spacer()

                Text("Review")
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: "EA4335"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
            .background(Color(hex: "EA4335").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "EA4335").opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Email Scan

    private func triggerEmailScan() {
        guard !hasScannedEmails,
              proAccess.isFeatureAvailable(.emailToTask),
              !emailAccountService.connectedAccounts.isEmpty else { return }
        hasScannedEmails = true
        isScanningEmails = true

        Task {
            let fetchService = EmailFetchService(accountService: emailAccountService)
            let emails = await fetchService.fetchAllAccounts()
            guard !emails.isEmpty else {
                await MainActor.run { isScanningEmails = false }
                return
            }
            let suggestions = await EmailScanService.shared.scan(emails: emails)
            await MainActor.run {
                emailSuggestions = suggestions
                isScanningEmails = false
            }
        }
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
            selectableRow(for: task)
        case .calendarEvent(let event):
            CalendarEventRow(event: event)
        case .habit(let habit):
            HabitTimelineRow(habit: habit)
        }
    }

    /// Wraps a TaskRowView with multi-select gestures + swipe actions + checkmark overlay.
    @ViewBuilder
    private func selectableRow(for task: FDTask) -> some View {
        let isSelected = selection.contains(task.id)
        let swipeOffset = taskSwipeOffsets[task.id] ?? 0
        let revealWidth: CGFloat = 68

        ZStack {
            // Complete action revealed by swipe-right
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        taskSwipeOffsets[task.id] = 0
                    }
                    Haptics.tock()
                    resolvedTaskService.toggleComplete(task)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                }
                .background(Color.fdGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(swipeOffset > 8 ? 1 : 0)
                Spacer()
            }

            // Delete action revealed by swipe-left
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        taskSwipeOffsets[task.id] = 0
                    }
                    Haptics.warning()
                    resolvedTaskService.deleteTask(task)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                }
                .background(Color.fdRed)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(swipeOffset < -8 ? 1 : 0)
            }

            TaskRowView(
                task: task,
                isExpanded: expandedTaskID == task.id,
                onToggle: { resolvedTaskService.toggleComplete(task) },
                onToggleSubtask: { sub in resolvedTaskService.toggleSubtaskComplete(sub) },
                onExpand: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        expandedTaskID = expandedTaskID == task.id ? nil : task.id
                    }
                }
            )
            .offset(x: swipeOffset)
            .overlay(alignment: .topLeading) {
                if selection.isActive {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Color.fdAccent : Color.fdTextMuted)
                        .padding(8)
                        .background(Circle().fill(Color.fdSurface))
                        .offset(x: -6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.fdAccent : .clear, lineWidth: isSelected ? 2 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if swipeOffset != 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        taskSwipeOffsets[task.id] = 0
                    }
                } else if selection.isActive {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection.toggle(task.id)
                    }
                    if selection.count == 0 {
                        withAnimation { selection.exit() }
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                if !selection.isActive && swipeOffset == 0 {
                    Haptics.tock()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        selection.enter(initial: task.id)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        guard !selection.isActive else { return }
                        let t = value.translation.width
                        withAnimation(.interactiveSpring()) {
                            taskSwipeOffsets[task.id] = max(-revealWidth, min(revealWidth, t))
                        }
                    }
                    .onEnded { value in
                        guard !selection.isActive else { return }
                        let t = value.translation.width
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if t > 44 {
                                taskSwipeOffsets[task.id] = revealWidth
                            } else if t < -44 {
                                taskSwipeOffsets[task.id] = -revealWidth
                            } else {
                                taskSwipeOffsets[task.id] = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .contextMenu {
            Button {
                requirePro(.focusTimerLinked) {
                    focusTimerPrelinkedTask = task.id
                    showFocusTimer = true
                }
            } label: {
                Label(proAccess.isFeatureAvailable(.focusTimerLinked)
                      ? "Start Focus"
                      : "Start Focus · Pro",
                      systemImage: "timer")
            }
            Button {
                Haptics.tock()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    selection.enter(initial: task.id)
                }
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
        }
    }

    private var emptyTimelineView: some View {
        EmptyStateView.todayEmpty(energy: appState.todayEnergy) {
            quickAddFocused = true
        }
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
                    selectableRow(for: task)
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
            .frame(height: 24)
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)

                TextField("Add a task...", text: $quickAddText)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .tint(Color.fdAccent)
                    .focused($quickAddFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        Haptics.tock()
                        resolvedTaskService.createTask(title: trimmed)
                        quickAddText = ""
                    }

                Button {
                    requirePro(.ramble) {
                        Haptics.tap()
                        showRamble = true
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "mic")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fdAccent)
                        if !proAccess.isFeatureAvailable(.ramble) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(Color.fdAccent, in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }
                }
                .accessibilityLabel("Ramble — dictate multiple tasks")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: -3)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .scaleEffect(quickAddFocused ? 1.01 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: quickAddFocused)
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
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
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
        .padding(.vertical, 16)
        .background(
            ZStack {
                Color.fdSurface
                LinearGradient(
                    colors: [color.opacity(0.09), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
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
                // Animated circle checkbox
                Button {
                    if task.isCompleted { Haptics.tap() } else { Haptics.tock() }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        onToggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? Color.fdGreen : priorityColor.opacity(0.55), lineWidth: 2)
                        if task.isCompleted {
                            Circle().fill(Color.fdGreen)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 22, height: 22)
                    .scaleEffect(task.isCompleted ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                .accessibilityLabel(task.isCompleted ? "Mark task incomplete" : "Complete task")

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.fdBody)
                        .foregroundStyle(task.isCompleted ? Color.fdTextMuted : Color.fdText)
                        .strikethrough(task.isCompleted)

                    // Metadata row
                    HStack(spacing: 8) {
                        // Project as colored dot + label
                        if let project = task.project {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: project.colorHex))
                                    .frame(width: 6, height: 6)
                                Text(project.name)
                                    .font(.fdMicro)
                                    .foregroundStyle(Color.fdTextSecondary)
                            }
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
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                                }
                                .font(.fdMono)
                                .foregroundStyle(Color.fdTextMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Due date chip
                    if let dueDate = task.dueDate {
                        dueDateChip(for: dueDate)
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
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onToggleSubtask(subtask)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(subtask.isCompleted ? Color.fdGreen : Color.fdBorder, lineWidth: 1.5)
                                    if subtask.isCompleted {
                                        Circle().fill(Color.fdGreen)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(subtask.isCompleted ? "Mark subtask incomplete" : "Complete subtask")

                            Text(subtask.title)
                                .font(.fdCaption)
                                .foregroundStyle(subtask.isCompleted ? Color.fdTextMuted : Color.fdTextSecondary)
                                .strikethrough(subtask.isCompleted)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.leading, 48)
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.fdSurface)
        .overlay(alignment: .leading) {
            // Left priority border strip
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func dueDateChip(for date: Date) -> some View {
        let isOverdue = date < Calendar.current.startOfDay(for: .now) && !task.isCompleted
        let isToday = Calendar.current.isDateInToday(date)
        let chipColor: Color = isOverdue ? .fdRed : isToday ? .fdAccent : .fdBlue

        return HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 9))
            Text(isToday ? "Today" : isOverdue ? "Overdue" : date.formatted(.dateTime.month(.abbreviated).day()))
        }
        .font(.fdMicro)
        .foregroundStyle(chipColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(chipColor.opacity(0.1))
        .clipShape(Capsule())
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
            let wasCompleted = habit.isCompletedToday
            if wasCompleted {
                Haptics.tap()
            } else {
                Haptics.success()
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                let _ = habit.toggleToday()
            }
            try? modelContext.save()
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Text(habit.emoji)
                        .font(.title2)
                        .scaleEffect(habit.isCompletedToday ? 1.12 : 1.0)
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
                            .transition(.scale.combined(with: .opacity))
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
