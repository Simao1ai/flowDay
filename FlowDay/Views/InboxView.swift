// InboxView.swift
// FlowDay

import SwiftUI
import SwiftData

struct InboxView: View {
    let taskService: TaskService?
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<FDTask> { !$0.isDeleted && !$0.isCompleted },
        sort: [SortDescriptor(\FDTask.createdAt, order: .reverse)]
    )
    private var allActiveTasks: [FDTask]

    private var inboxTasks: [FDTask] {
        allActiveTasks.filter { $0.scheduledTime == nil && $0.dueDate == nil }
    }

    @State private var newTaskText = ""
    @FocusState private var isAddingTask: Bool
    @State private var selectedTask: FDTask?
    @State private var showSmartAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickCaptureField
                    taskList
             }
                .padding(20)
            }
            .background(Color.fdBackground)
            .navigationTitle("Inbox")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSmartAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fdAccent)
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, taskService: taskService)
            }
            .sheet(isPresented: $showSmartAdd) {
                SmartQuickAddView(taskService: taskService, onDismiss: { showSmartAdd = false })
            }
        }
    }

    private var quickCaptureField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.fdAccent)
            TextField("Capture a thought...", text: $newTaskText)
                .font(.fdBody)
                .focused($isAddingTask)
                .submitLabel(.done)
                .onSubmit {
                    guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    taskService?.createTask(title: newTaskText)
                    newTaskText = ""
                }
        }
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var taskList: some View {
        if inboxTasks.isEmpty {
            emptyState
        } else {
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 11))
                Text("\(inboxTasks.count) items")
            }
            .fdSectionHeader()

            LazyVStack(spacing: 10) {
                ForEach(inboxTasks) { task in
                    inboxRow(task)
                        .onTapGesture { selectedTask = task }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(Color.fdAccent.opacity(0.4))
            Text("Inbox zero")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("All tasks are organized. Nice work.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func inboxRow(_ task: FDTask) -> some View {
        HStack(spacing: 12) {
            Button {
                taskService?.toggleComplete(task)
            } label: {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.fdBorder, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            priorityBadge(task.priority)
        }
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        Text(priority.label)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.12))
            .foregroundStyle(priority.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
