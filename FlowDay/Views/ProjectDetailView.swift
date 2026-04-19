// ProjectDetailView.swift
// FlowDay
//
// Shows all tasks within a project, grouped by section. Sections let users
// break a project into columns like "Backlog / In Progress / Done" —
// closing one of Todoist's most-used organizational primitives.

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: FDProject
    let taskService: TaskService?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskSection: String? = nil
    @State private var expandedTaskID: UUID?
    @State private var selectedTask: FDTask?
    @State private var showAddSection = false
    @State private var newSectionName = ""
    @State private var editingSection: String?
    @State private var editingSectionName = ""
    @State private var collapsedSections: Set<String> = []

    private func sortedActiveTasks(in section: String?) -> [FDTask] {
        project.tasks
            .filter { !$0.isDeleted && !$0.isCompleted && $0.section == section }
            .sorted { ($0.priority.rawValue, $0.sortOrder) < ($1.priority.rawValue, $1.sortOrder) }
    }

    private var completedTasks: [FDTask] {
        project.tasks
            .filter { !$0.isDeleted && $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Distinct sections in display order: project.sections first,
    /// then any orphaned section names referenced by tasks but not in the list.
    private var orderedSectionNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
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

    /// "No section" bucket — only shown when it contains tasks.
    private var hasUngroupedTasks: Bool {
        project.tasks.contains { !$0.isDeleted && !$0.isCompleted && ($0.section == nil || $0.section == "") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    projectHeader

                    // Ungrouped tasks — only show if there are any
                    if hasUngroupedTasks {
                        sectionBlock(
                            title: "No Section",
                            icon: "tray",
                            sectionKey: nil,
                            tasks: sortedActiveTasks(in: nil),
                            canRename: false
                        )
                    }

                    // Named sections
                    ForEach(orderedSectionNames, id: \.self) { name in
                        sectionBlock(
                            title: name,
                            icon: "square.stack.3d.up",
                            sectionKey: name,
                            tasks: sortedActiveTasks(in: name),
                            canRename: true
                        )
                    }

                    // Add a section
                    addSectionRow

                    // Completed tasks
                    if !completedTasks.isEmpty {
                        completedBlock
                    }

                    // Empty state
                    if project.tasks.filter({ !$0.isDeleted }).isEmpty && project.sections.isEmpty {
                        emptyState
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
                    Button {
                        newTaskSection = nil
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.fdAccent)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                Button {
                    newTaskSection = nil
                    showAddTask = true
                } label: {
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
            .sheet(isPresented: $showAddTask) { addTaskSheet }
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
            .alert("Rename Section", isPresented: Binding(
                get: { editingSection != nil },
                set: { if !$0 { editingSection = nil } }
            )) {
                TextField("Name", text: $editingSectionName)
                Button("Save") {
                    if let old = editingSection, let taskService {
                        Haptics.tap()
                        taskService.renameSection(old, to: editingSectionName, in: project)
                    }
                    editingSection = nil
                }
                Button("Cancel", role: .cancel) { editingSection = nil }
            }
        }
    }

    // MARK: - Section Block

    @ViewBuilder
    private func sectionBlock(
        title: String,
        icon: String,
        sectionKey: String?,
        tasks: [FDTask],
        canRename: Bool
    ) -> some View {
        let isCollapsed = sectionKey.map { collapsedSections.contains($0) } ?? false

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    if let key = sectionKey {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if collapsedSections.contains(key) {
                                collapsedSections.remove(key)
                            } else {
                                collapsedSections.insert(key)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 11))
                        Text(title)
                        if sectionKey != nil {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        }
                        Text("\(tasks.count)")
                            .font(.fdMicroBold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.fdSurfaceHover)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .fdSectionHeader()

                Spacer()

                // Per-section menu (add task here / rename / delete)
                if canRename, let key = sectionKey {
                    Menu {
                        Button {
                            newTaskSection = key
                            showAddTask = true
                        } label: {
                            Label("Add task to section", systemImage: "plus")
                        }
                        Button {
                            editingSection = key
                            editingSectionName = key
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            Haptics.warning()
                            taskService?.deleteSection(key, in: project)
                        } label: {
                            Label("Delete section", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fdTextMuted)
                            .frame(width: 24, height: 24)
                    }
                }
            }

            if !isCollapsed {
                if tasks.isEmpty {
                    emptySectionPlaceholder(sectionKey: sectionKey)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(tasks) { task in
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
                            .contextMenu {
                                sectionMoveMenu(for: task)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionMoveMenu(for task: FDTask) -> some View {
        Menu("Move to section") {
            Button {
                taskService?.moveTask(task, to: nil)
            } label: {
                Label("No Section", systemImage: "tray")
            }
            ForEach(orderedSectionNames, id: \.self) { name in
                Button {
                    taskService?.moveTask(task, to: name)
                } label: {
                    Label(name, systemImage: "square.stack.3d.up")
                }
            }
        }
    }

    private func emptySectionPlaceholder(sectionKey: String?) -> some View {
        Button {
            newTaskSection = sectionKey
            showAddTask = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add a task")
                    .font(.fdCaption)
            }
            .foregroundStyle(Color.fdTextMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fdSurfaceHover.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fdBorderLight, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Section Row

    private var addSectionRow: some View {
        Button {
            newSectionName = ""
            showAddSection = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add section")
                    .font(.fdCaptionBold)
            }
            .foregroundStyle(Color.fdAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.fdAccentLight.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed

    private var completedBlock: some View {
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: project.iconName ?? "folder")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: project.colorHex).opacity(0.4))
            Text("No tasks yet")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("Add your first task or create sections to organize your work.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
                Text("\(project.activeTasks.count) active tasks")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)

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

                if !orderedSectionNames.isEmpty {
                    Menu {
                        Button { newTaskSection = nil } label: {
                            Label("No Section", systemImage: "tray")
                        }
                        ForEach(orderedSectionNames, id: \.self) { name in
                            Button { newTaskSection = name } label: {
                                Label(name, systemImage: "square.stack.3d.up")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: newTaskSection == nil ? "tray" : "square.stack.3d.up")
                                .font(.system(size: 13))
                            Text(newTaskSection ?? "No Section")
                                .font(.fdBody)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.fdText)
                        .padding(14)
                        .background(Color.fdSurfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

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
                        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        Haptics.tock()
                        if let taskService {
                            taskService.createTask(title: trimmed, project: project, section: newTaskSection)
                        } else {
                            let task = FDTask(title: trimmed, section: newTaskSection, project: project)
                            modelContext.insert(task)
                            try? modelContext.save()
                        }
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
