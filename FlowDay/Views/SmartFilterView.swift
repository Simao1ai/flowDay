// SmartFilterView.swift
// FlowDay
//
// Renders a task list filtered by a SmartFilter — reused by every preset
// (Today, Overdue, etc.). Keeps all filter views visually consistent and
// avoids one-off list screens per filter.

import SwiftUI
import SwiftData

struct SmartFilterView: View {
    let filter: SmartFilter
    let taskService: TaskService?

    @Environment(\.dismiss) private var dismiss
    @Query private var allTasksRaw: [FDTask]

    @State private var expandedTaskID: UUID?
    @State private var selectedTask: FDTask?

    private var matchingTasks: [FDTask] {
        allTasksRaw
            .filter { filter.matches($0) }
            .sorted { filter.sortKey(for: $0) < filter.sortKey(for: $1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matchingTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .background(Color.fdBackground)
            .navigationTitle(filter.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fdText)
                            .frame(width: 36, height: 36)
                            .background(Color.fdSurfaceHover)
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: filter.iconName)
                            .font(.system(size: 11))
                        Text("\(matchingTasks.count)")
                            .font(.fdCaptionBold)
                    }
                    .foregroundStyle(filter.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(filter.tint.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, taskService: taskService)
            }
        }
    }

    // MARK: - List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(matchingTasks) { task in
                    TaskRowView(
                        task: task,
                        isExpanded: expandedTaskID == task.id,
                        onToggle: { taskService?.toggleComplete(task) },
                        onToggleSubtask: { sub in taskService?.toggleSubtaskComplete(sub) },
                        onExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedTaskID = expandedTaskID == task.id ? nil : task.id
                            }
                        }
                    )
                    .onTapGesture { selectedTask = task }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(filter.tint.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: filter.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(filter.tint)
            }
            Text(filter.emptyMessage)
                .font(.fdBody)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
