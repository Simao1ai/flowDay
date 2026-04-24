// UpcomingView.swift
// FlowDay

import SwiftUI
import SwiftData

struct UpcomingView: View {
    let taskService: TaskService?
    @Environment(\.modelContext) private var modelContext

    // Plain @Query — no predicates (crash on iOS 26.x). Filtered in computed props.
    @Query
    private var upcomingTasksRaw: [FDTask]

    private var upcomingTasks: [FDTask] {
        upcomingTasksRaw
            .filter { !$0.isDeleted && !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    @State private var selectedTask: FDTask?
    @State private var showSmartAdd = false
    @State private var viewMode: UpcomingViewMode = .list
    @State private var showWeekViewPaywall = false

    private enum UpcomingViewMode { case list, week }

    private var futureTasks: [FDTask] {
        upcomingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return !Calendar.current.isDateInToday(due)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewMode == .list {
                    listContent
                } else {
                    WeekView(taskService: taskService, selectedTask: $selectedTask)
                }
            }
            .background(Color.fdBackground)
            .navigationTitle("Upcoming")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            if viewMode == .week {
                                withAnimation(.easeInOut(duration: 0.2)) { viewMode = .list }
                            } else if ProAccessManager.shared.isFeatureAvailable(.weekView) {
                                withAnimation(.easeInOut(duration: 0.2)) { viewMode = .week }
                            } else {
                                showWeekViewPaywall = true
                            }
                        } label: {
                            Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.fdAccent)
                        }
                        Button { showSmartAdd = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.fdAccent)
                        }
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, taskService: taskService)
            }
            .sheet(isPresented: $showSmartAdd) {
                SmartQuickAddView(taskService: taskService, onDismiss: { showSmartAdd = false })
            }
            .paywall(isPresented: $showWeekViewPaywall, feature: .weekView)
        }
    }

    // MARK: - List content

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if futureTasks.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(futureTasks) { task in
                            upcomingTaskRow(task)
                                .onTapGesture { selectedTask = task }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(Color.fdAccent.opacity(0.4))
            Text("All clear ahead")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("No upcoming tasks. Enjoy the open road.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func upcomingTaskRow(_ task: FDTask) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .stroke(task.priority.color.opacity(0.5), lineWidth: 2)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                taskMetadata(task)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }

    private func taskMetadata(_ task: FDTask) -> some View {
        HStack(spacing: 8) {
            if let due = task.dueDate {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                }
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
            }
            if let project = task.project {
                Text(project.name)
                    .font(.fdMicro)
                    .foregroundStyle(Color(hex: project.colorHex))
            }
        }
    }
}
