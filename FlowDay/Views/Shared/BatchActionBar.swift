// BatchActionBar.swift
// FlowDay
//
// Bottom action bar shown when SelectionState.isActive == true. Lets the
// user complete / delete / reschedule the selected tasks in one shot.

import SwiftUI
import SwiftData

struct BatchActionBar: View {
    @Bindable var selection: SelectionState
    let taskService: TaskService?
    let allTasks: [FDTask]

    @State private var showRescheduleSheet = false
    @State private var rescheduleDate = Date.now
    @State private var showDeleteConfirm = false

    private var selectedTasks: [FDTask] {
        allTasks.filter { selection.contains($0.id) }
    }

    var body: some View {
        if selection.isActive {
            VStack(spacing: 0) {
                Divider().background(Color.fdBorder)
                HStack(spacing: 18) {
                    actionButton(icon: "checkmark.circle", label: "Complete", tint: .fdGreen) {
                        Haptics.success()
                        for task in selectedTasks { taskService?.toggleComplete(task) }
                        selection.exit()
                    }

                    actionButton(icon: "calendar", label: "Reschedule", tint: .fdBlue) {
                        Haptics.tap()
                        rescheduleDate = .now
                        showRescheduleSheet = true
                    }

                    actionButton(icon: "trash", label: "Delete", tint: .fdRed) {
                        Haptics.warning()
                        showDeleteConfirm = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.fdSurface)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $showRescheduleSheet) { rescheduleSheet }
            .alert("Delete \(selection.count) task\(selection.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Haptics.error()
                    for task in selectedTasks { taskService?.deleteTask(task) }
                    selection.exit()
                }
            } message: {
                Text("They'll be moved to the recycle bin and can be restored from Undo.")
            }
        }
    }

    private func actionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.fdMicroBold)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var rescheduleSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("Reschedule to", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()

                HStack(spacing: 10) {
                    quickRescheduleChip(label: "Today", date: .now)
                    quickRescheduleChip(label: "Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
                    quickRescheduleChip(label: "Next week", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: .now) ?? .now)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Reschedule \(selection.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRescheduleSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Haptics.tock()
                        for task in selectedTasks {
                            taskService?.rescheduleTask(task, to: rescheduleDate)
                        }
                        showRescheduleSheet = false
                        selection.exit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fdAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func quickRescheduleChip(label: String, date: Date) -> some View {
        Button {
            Haptics.tap()
            rescheduleDate = date
        } label: {
            Text(label)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Header chip shown above lists when selection is active

struct SelectionHeader: View {
    @Bindable var selection: SelectionState

    var body: some View {
        if selection.isActive {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    selection.exit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.fdText)
                        .frame(width: 26, height: 26)
                        .background(Color.fdSurfaceHover)
                        .clipShape(Circle())
                }
                Text("\(selection.count) selected")
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.fdAccentLight)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
