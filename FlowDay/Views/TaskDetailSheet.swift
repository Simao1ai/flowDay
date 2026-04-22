// TaskDetailSheet.swift
// FlowDay
//
// Todoist shows a detail sheet when you tap a task (screenshot 2).
// FlowDay's version adds: energy level, start date, inline subtask add.

import SwiftUI
import SwiftData

struct TaskDetailSheet: View {
    @Bindable var task: FDTask
    let taskService: TaskService?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query
    private var projectsRaw: [FDProject]

    private var projects: [FDProject] {
        projectsRaw.sorted { $0.name < $1.name }
    }

    @State private var newSubtaskText = ""
    @FocusState private var subtaskFieldFocused: Bool
    @State private var showDatePicker = false
    @State private var showStartDatePicker = false
    @State private var showTimePicker = false
    @State private var showAttachmentPicker = false
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title section
                        titleSection

                        Divider().padding(.horizontal, 20)

                        // Metadata fields
                        metadataSection

                        Divider().padding(.horizontal, 20)

                        // Subtasks
                        subtasksSection

                        // Notes
                        notesSection

                        // Attachments
                        if !task.attachments.isEmpty {
                            Divider().padding(.horizontal, 20)
                            attachmentsSection
                        }
                    }
                }
                .background(Color.fdBackground)

                // Copied toast
                if showCopiedToast {
                    toastBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAttachmentPicker = true
                    } label: {
                        Image(systemName: "paperclip")
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = "flowday://task/\(task.id.uuidString)"
                            withAnimation(.spring(response: 0.3)) { showCopiedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.spring(response: 0.3)) { showCopiedToast = false }
                            }
                        } label: {
                            Label("Copy Link", systemImage: "link")
                        }
                        Button(role: .destructive) {
                            taskService?.deleteTask(task)
                            dismiss()
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAttachmentPicker) {
                AttachmentPickerView(task: task)
            }
        }
    }

    // MARK: - Toast

    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.fdGreen)
            Text("Link copied")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.fdSurface)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Title

    private var titleSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                taskService?.toggleComplete(task)
            } label: {
                checkboxView
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            TextField("Task name", text: $task.title, axis: .vertical)
                .font(.fdTitle3)
                .foregroundStyle(task.isCompleted ? Color.fdTextMuted : Color.fdText)
                .strikethrough(task.isCompleted)
                .onChange(of: task.title) {
                    task.modifiedAt = .now
                    try? modelContext.save()
                }
        }
        .padding(20)
    }

    private var checkboxView: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(task.isCompleted ? Color.fdGreen : task.priority.color.opacity(0.5), lineWidth: 2)
            .fill(task.isCompleted ? Color.fdGreen : Color.clear)
            .frame(width: 24, height: 24)
            .overlay {
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 0) {
            // Project
            metadataRow(icon: "number", label: "Project", iconColor: .fdAccent) {
                projectPicker
            }

            // Priority
            metadataRow(icon: "flag.fill", label: "Priority", iconColor: task.priority.color) {
                priorityPicker
            }

            // Due Date
            metadataRow(icon: "calendar", label: "Due Date", iconColor: .fdRed) {
                dueDateField
            }

            // Start Date (FlowDay exclusive!)
            metadataRow(icon: "calendar.badge.clock", label: "Start Date", iconColor: .fdBlue) {
                startDateField
            }

            // Scheduled Time
            metadataRow(icon: "clock", label: "Scheduled Time", iconColor: .fdPurple) {
                scheduledTimeField
            }

            // Duration
            metadataRow(icon: "timer", label: "Duration", iconColor: .fdGreen) {
                durationField
            }

            // Recurrence
            if let rule = task.recurrenceRule {
                metadataRow(icon: "repeat", label: "Repeats", iconColor: .fdYellow) {
                    Text(recurrenceDisplayText(rule))
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                }
            }

            // Labels
            if !task.labels.isEmpty {
                metadataRow(icon: "tag", label: "Labels", iconColor: .fdTextSecondary) {
                    HStack(spacing: 6) {
                        ForEach(task.labels, id: \.self) { label in
                            Text("@\(label)")
                                .font(.fdMicro)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.fdAccentLight)
                                .foregroundStyle(Color.fdAccent)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func metadataRow<Content: View>(
        icon: String,
        label: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .frame(width: 100, alignment: .leading)

            content()

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Field Views

    private var projectPicker: some View {
        Menu {
            Button("None") {
                task.project = nil
                try? modelContext.save()
            }
            ForEach(projects) { project in
                Button {
                    task.project = project
                    try? modelContext.save()
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 8, height: 8)
                        Text(project.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let project = task.project {
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 8, height: 8)
                    Text(project.name)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                } else {
                    Text("Add project")
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
        }
    }

    private var priorityPicker: some View {
        Menu {
            ForEach(TaskPriority.allCases, id: \.self) { p in
                Button {
                    task.priority = p
                    try? modelContext.save()
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(p.color)
                        Text(p.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(task.priority.label)
                    .font(.fdBodySemibold)
                    .foregroundStyle(task.priority.color)
            }
        }
    }

    private var dueDateField: some View {
        Group {
            if let date = task.dueDate {
                Button {
                    showDatePicker.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.fdBody)
                            .foregroundStyle(task.isOverdue ? Color.fdRed : Color.fdText)
                        Button {
                            task.dueDate = nil
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                }
            } else {
                Button("Add date") {
                    task.dueDate = .now
                    showDatePicker = true
                }
                .font(.fdBody)
                .foregroundStyle(Color.fdTextMuted)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet(
                title: "Due Date",
                date: Binding(
                    get: { task.dueDate ?? .now },
                    set: { task.dueDate = $0; try? modelContext.save() }
                )
            )
        }
    }

    private var startDateField: some View {
        Group {
            if let date = task.startDate {
                Button {
                    showStartDatePicker.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                        Button {
                            task.startDate = nil
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                }
            } else {
                Button("Add start date") {
                    task.startDate = .now
                    showStartDatePicker = true
                }
                .font(.fdBody)
                .foregroundStyle(Color.fdTextMuted)
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            datePickerSheet(
                title: "Start Date",
                date: Binding(
                    get: { task.startDate ?? .now },
                    set: { task.startDate = $0; try? modelContext.save() }
                )
            )
        }
    }

    private var scheduledTimeField: some View {
        Group {
            if let time = task.scheduledTime {
                HStack(spacing: 4) {
                    Text(time.formatted(.dateTime.hour().minute()))
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                    Button {
                        task.scheduledTime = nil
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            } else {
                Button("Set time") {
                    task.scheduledTime = .now
                    showTimePicker = true
                }
                .font(.fdBody)
                .foregroundStyle(Color.fdTextMuted)
            }
        }
    }

    private var durationField: some View {
        Menu {
            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                Button {
                    task.estimatedMinutes = mins
                    try? modelContext.save()
                } label: {
                    Text(durationText(mins))
                }
            }
            Button("None") {
                task.estimatedMinutes = nil
                try? modelContext.save()
            }
        } label: {
            if let mins = task.estimatedMinutes {
                Text(durationText(mins))
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
            } else {
                Text("Add estimate")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
    }

    // MARK: - Subtasks

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                Text("Subtasks")
            }
            .fdSectionHeader()
            .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(task.subtasks.sorted(by: { $0.sortOrder < $1.sortOrder })) { subtask in
                    subtaskRow(subtask)
                }
            }

            // Inline add subtask
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fdAccent)

                TextField("Add subtask...", text: $newSubtaskText)
                    .font(.fdCaption)
                    .focused($subtaskFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        taskService?.addSubtask(to: task, title: newSubtaskText)
                        newSubtaskText = ""
                        subtaskFieldFocused = true
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 16)
    }

    private func subtaskRow(_ subtask: FDSubtask) -> some View {
        HStack(spacing: 10) {
            Button {
                taskService?.toggleSubtaskComplete(subtask)
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(subtask.isCompleted ? Color.fdGreen : Color.fdBorder, lineWidth: 1.5)
                    .fill(subtask.isCompleted ? Color.fdGreen : Color.clear)
                    .frame(width: 16, height: 16)
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
                .foregroundStyle(subtask.isCompleted ? Color.fdTextMuted : Color.fdText)
                .strikethrough(subtask.isCompleted)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                Text("Notes")
            }
            .fdSectionHeader()
            .padding(.horizontal, 20)

            TextField("Add notes...", text: $task.notes, axis: .vertical)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .lineLimit(3...10)
                .onChange(of: task.notes) {
                    task.modifiedAt = .now
                    try? modelContext.save()
                }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func datePickerSheet(title: String, date: Binding<Date>) -> some View {
        NavigationStack {
            DatePicker(title, selection: date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.fdAccent)
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showDatePicker = false; showStartDatePicker = false }
                            .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private func durationText(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    // MARK: - Attachments

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                Text("Attachments")
            }
            .fdSectionHeader()
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(task.attachments) { attachment in
                        AttachmentThumbnailView(attachment: attachment) {
                            task.removeAttachment(id: attachment.id)
                            try? modelContext.save()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 16)
    }

    private func recurrenceDisplayText(_ rule: String) -> String {
        if rule.contains("DAILY") { return "Every day" }
        if rule.contains("WEEKLY") {
            if rule.contains("BYDAY=MO") { return "Every Monday" }
            if rule.contains("BYDAY=TU") { return "Every Tuesday" }
            if rule.contains("BYDAY=WE") { return "Every Wednesday" }
            if rule.contains("BYDAY=TH") { return "Every Thursday" }
            if rule.contains("BYDAY=FR") { return "Every Friday" }
            if rule.contains("BYDAY=SA") { return "Every Saturday" }
            if rule.contains("BYDAY=SU") { return "Every Sunday" }
            if rule.contains("MO,TU,WE,TH,FR") { return "Every weekday" }
            return "Every week"
        }
        if rule.contains("MONTHLY") { return "Every month" }
        return rule
    }
}
