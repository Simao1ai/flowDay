// BoardView.swift
// FlowDay
//
// Kanban board rendering of a project — one column per section. Tasks can
// be dragged across columns to change their section, matching Todoist's
// Board view but with FlowDay's warm aesthetic.

import SwiftUI
import SwiftData

struct BoardView: View {
    let project: FDProject
    let taskService: TaskService?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTask: FDTask?
    @State private var showAddSection = false
    @State private var newSectionName = ""
    @State private var draggingTaskId: UUID?

    /// "No Section" column is always shown first if tasks live there; then
    /// named sections in the project's declared order; then any orphans.
    private var columnKeys: [String?] {
        var result: [String?] = []
        let hasUngrouped = project.tasks.contains { !$0.isDeleted && !$0.isCompleted && ($0.section == nil || $0.section == "") }
        if hasUngrouped { result.append(nil) }

        var seen = Set<String>()
        for name in project.sections where seen.insert(name).inserted {
            result.append(name)
        }
        for task in project.tasks {
            if let s = task.section, !s.isEmpty, seen.insert(s).inserted {
                result.append(s)
            }
        }
        return result
    }

    private func tasks(in section: String?) -> [FDTask] {
        project.tasks
            .filter { !$0.isDeleted && !$0.isCompleted && $0.section == section }
            .sorted { ($0.priority.rawValue, $0.sortOrder) < ($1.priority.rawValue, $1.sortOrder) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(columnKeys, id: \.self) { key in
                    BoardColumn(
                        title: key ?? "No Section",
                        isPlaceholder: key == nil,
                        tasks: tasks(in: key),
                        accentColor: Color(hex: project.colorHex),
                        onAddTask: { addQuickTask(to: key) },
                        onTaskTap: { task in selectedTask = task },
                        onDropTask: { taskID in
                            moveTask(withID: taskID, to: key)
                        },
                        draggingTaskId: $draggingTaskId
                    )
                }

                addColumnButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.fdBackground)
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task, taskService: taskService)
        }
        .alert("New Section", isPresented: $showAddSection) {
            TextField("Name", text: $newSectionName)
            Button("Add") {
                guard let taskService else { return }
                Haptics.tap()
                taskService.addSection(newSectionName, to: project)
                newSectionName = ""
            }
            Button("Cancel", role: .cancel) { newSectionName = "" }
        }
    }

    private var addColumnButton: some View {
        Button {
            newSectionName = ""
            showAddSection = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 20))
                Text("Add section")
                    .font(.fdCaptionBold)
            }
            .foregroundStyle(Color.fdAccent)
            .frame(width: 280, height: 120)
            .background(Color.fdAccentLight.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.fdAccent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func moveTask(withID id: UUID, to section: String?) {
        guard let task = project.tasks.first(where: { $0.id == id }) else { return }
        guard task.section != section else { return }
        Haptics.tock()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            taskService?.moveTask(task, to: section)
        }
    }

    private func addQuickTask(to section: String?) {
        guard let taskService else { return }
        Haptics.tap()
        taskService.createTask(title: "New task", project: project, section: section)
    }
}

// MARK: - Column

private struct BoardColumn: View {
    let title: String
    let isPlaceholder: Bool
    let tasks: [FDTask]
    let accentColor: Color
    let onAddTask: () -> Void
    let onTaskTap: (FDTask) -> Void
    let onDropTask: (UUID) -> Void
    @Binding var draggingTaskId: UUID?

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        BoardCard(task: task, accentColor: accentColor)
                            .onTapGesture { onTaskTap(task) }
                            .draggable(task.id.uuidString) {
                                BoardCard(task: task, accentColor: accentColor)
                                    .frame(width: 260)
                                    .opacity(0.9)
                                    .onAppear { draggingTaskId = task.id }
                            }
                    }

                    Button(action: onAddTask) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add task")
                                .font(.fdCaption)
                        }
                        .foregroundStyle(Color.fdTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.fdSurfaceHover.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.fdBorderLight, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(width: 280)
        .frame(minHeight: 340)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTargeted ? accentColor.opacity(0.12) : Color.fdSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isTargeted ? accentColor : Color.fdBorderLight, lineWidth: isTargeted ? 2 : 1)
        )
        .dropDestination(for: String.self) { items, _ in
            draggingTaskId = nil
            guard let raw = items.first, let uuid = UUID(uuidString: raw) else { return false }
            onDropTask(uuid)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = targeted
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: isPlaceholder ? "tray" : "square.stack.3d.up")
                .font(.system(size: 11))
                .foregroundStyle(Color.fdTextMuted)
            Text(title)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
            Text("\(tasks.count)")
                .font(.fdMicroBold)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
            Spacer()
        }
    }
}

// MARK: - Card

private struct BoardCard: View {
    let task: FDTask
    let accentColor: Color

    private var priorityColor: Color { Color(task.priority.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(task.priority.label)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(task.title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 10) {
                if let mins = task.estimatedMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(mins)m")
                    }
                    .font(.fdMono)
                    .foregroundStyle(Color.fdTextMuted)
                }

                if !task.subtasks.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist")
                            .font(.system(size: 9))
                        Text("\(task.subtasks.filter(\.isCompleted).count)/\(task.subtasks.count)")
                    }
                    .font(.fdMono)
                    .foregroundStyle(Color.fdTextMuted)
                }

                if let due = task.dueDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(due.formatted(.dateTime.month(.abbreviated).day()))
                    }
                    .font(.fdMono)
                    .foregroundStyle(task.isOverdue ? Color.fdRed : Color.fdTextMuted)
                }

                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fdSurfaceHover.opacity(0.35))
        .overlay(
            Rectangle()
                .fill(priorityColor.opacity(0.7))
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
