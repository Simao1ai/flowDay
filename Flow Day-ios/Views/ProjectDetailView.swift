// ProjectDetailView.swift
// FlowDay
//
// Shows all tasks within a project with completion tracking.

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: FDProject
    let taskService: TaskService?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTask = false
    @State private var newTaskTitle = ""
    @State private var expandedTaskID: UUID?
    @State private var selectedTask: FDTask?

    private var activeTasks: [FDTask] {
        project.tasks
            .filter { !$0.isDeleted && !$0.isCompleted }
            .sorted { ($0.priority.rawValue, $0.sortOrder) < ($1.priority.rawValue, $1.sortOrder) }
    }

    private var completedTasks: [FDTask] {
        project.tasks
            .filter { !$0.isDeleted && $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project header
                    projectHeader

                    // Active tasks
                    if !activeTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11))
                                Text("Tasks")
                            }
                            .fdSectionHeader()

                            LazyVStack(spacing: 8) {
                                ForEach(activeTasks) { task in
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
                                    .onTapGesture {
                                        selectedTask = task
                                    }
                                }
                            }
                        }
                    }

                    // Completed tasks
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 11))
                                Text("Completed (\(completedTasks.count))")
                            }
                            .fdSectionHeader()

                            LazyVStack(spacing: 8) {
                                ForEach(completedTasks.prefix(5)) { task in
                                    TaskRowView(
                                        task: task,
                                        isExpanded: false,
                                        onToggle: { taskService?.toggleComplete(task) },
                                        onToggleSubtask: { _ in },
                                        onExpand: {}
                                    )
                                }
                            }
                        }
                    }

                    // Empty state
                    if activeTasks.isEmpty && completedTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: project.iconName ?? "folder")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(hex: project.colorHex).opacity(0.4))
                            Text("No tasks yet")
                                .font(.fdTitle3)
                                .foregroundStyle(Color.fdText)
                            Text("Add your first task to get started.")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.fdBackground)
            .navigationTitle(project.name)
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
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.fdAccent)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                // Quick add bar
                Button { showAddTask = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fdAccent)
                        Text("Add a task...")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: -2)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showAddTask) {
                addTaskSheet
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, taskService: taskService)
            }
        }
    }

    // MARK: - Project Header

    private var projectHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: project.iconName ?? "folder")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: project.colorHex))
                .frame(width: 44, height: 44)
                .background(Color(hex: project.colorHex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(activeTasks.count) active tasks")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.fdBorderLight)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: project.colorHex))
                            .frame(width: max(0, geo.size.width * project.completionRate), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            Text("\(Int(project.completionRate * 100))%")
                .font(.fdCaptionBold)
                .foregroundStyle(Color(hex: project.colorHex))
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }

    // MARK: - Add Task Sheet

    private var addTaskSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Task name", text: $newTaskTitle)
                    .font(.fdBody)
                    .padding(14)
                    .background(Color.fdSurfaceHover)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(20)
            .background(Color.fdBackground)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        newTaskTitle = ""
                        showAddTask = false
                    }
                    .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard !newTaskTitle.isEmpty else { return }
                        let task = FDTask(title: newTaskTitle, project: project)
                        modelContext.insert(task)
                        try? modelContext.save()
                        newTaskTitle = ""
                        showAddTask = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fdAccent)
                    .disabled(newTaskTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
