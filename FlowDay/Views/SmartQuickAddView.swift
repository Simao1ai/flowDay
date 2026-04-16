// SmartQuickAddView.swift
// FlowDay
//
// Todoist's natural language input with parsed chips.
// "Review contract from Sarah by Friday 13:00 p2 #Work"
// → Shows parsed pills: [Friday 13:00] [P2] [Work]
// FlowDay also shows: [45m] [every Monday] [@urgent]

import SwiftUI
import SwiftData

struct SmartQuickAddView: View {
    let taskService: TaskService?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\FDProject.name)])
    private var projects: [FDProject]

    @State private var inputText = ""
    @State private var parsedResult: ParsedTask?
    @State private var showDatePicker = false
    @State private var selectedDate: Date = .now
    @State private var manualPriority: TaskPriority? = nil
    @FocusState private var isFocused: Bool

    private let parser = NaturalLanguageParser()

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            handleBar

            // Input field
            inputSection

            // Parsed chips
            if let parsed = parsedResult, hasAnyParsedData(parsed) {
                chipsSection(parsed)
            }

            // Quick action buttons
            quickActions

            Spacer(minLength: 0)
        }
        .background(Color.fdSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: .black.opacity(0.15), radius: 30, y: -5)
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.fdBorder)
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // MARK: - Input

    private var inputSection: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.fdTextMuted)
            }

            TextField("What needs to be done?", text: $inputText, axis: .vertical)
                .font(.fdBody)
                .focused($isFocused)
                .lineLimit(1...4)
                .submitLabel(.done)
                .onChange(of: inputText) { _, newValue in
                    if !newValue.isEmpty {
                        parsedResult = parser.parse(newValue)
                    } else {
                        parsedResult = nil
                    }
                }
                .onSubmit {
                    submitTask()
                }

            Button {
                submitTask()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(inputText.isEmpty ? Color.fdTextMuted : Color.fdAccent)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Parsed Chips

    private func chipsSection(_ parsed: ParsedTask) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date chip
                if let date = parsed.dueDate {
                    parsedChip(
                        icon: "calendar",
                        text: formatDateChip(date),
                        color: .fdRed
                    )
                }

                // Time chip
                if let time = parsed.scheduledTime {
                    parsedChip(
                        icon: "clock",
                        text: time.formatted(.dateTime.hour().minute()),
                        color: .fdPurple
                    )
                }

                // Priority chip
                if parsed.priority != .none {
                    parsedChip(
                        icon: "flag.fill",
                        text: parsed.priority.label,
                        color: parsed.priority.color
                    )
                }

                // Project chip
                if let projectName = parsed.projectName {
                    parsedChip(
                        icon: "number",
                        text: projectName,
                        color: projectColor(for: projectName)
                    )
                }

                // Duration chip
                if let mins = parsed.estimatedMinutes {
                    parsedChip(
                        icon: "timer",
                        text: durationText(mins),
                        color: .fdGreen
                    )
                }

                // Recurrence chip
                if let rule = parsed.recurrenceRule {
                    parsedChip(
                        icon: "repeat",
                        text: recurrenceShort(rule),
                        color: .fdYellow
                    )
                }

                // Label chips
                ForEach(parsed.labels, id: \.self) { label in
                    parsedChip(
                        icon: "tag",
                        text: label,
                        color: .fdAccent
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.fdSurfaceHover)
    }

    private func parsedChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.fdMicroBold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Date picker button
                Button {
                    showDatePicker.toggle()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        Text("Date")
                            .font(.fdMicro)
                    }
                    .foregroundStyle(showDatePicker ? Color.fdAccent : Color.fdTextSecondary)
                }

                quickActionButton(icon: "sun.max", label: "Today") {
                    appendToInput(" today")
                }
                quickActionButton(icon: "arrow.right.circle", label: "Tomorrow") {
                    appendToInput(" tomorrow")
                }

                // Priority cycle: none → P4 → P3 → P2 → P1
                Button {
                    cyclePriority()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "flag")
                            .font(.system(size: 14))
                        Text(manualPriority?.label ?? "Priority")
                            .font(.fdMicro)
                    }
                    .foregroundStyle(manualPriority?.color ?? Color.fdTextSecondary)
                }

                quickActionButton(icon: "number", label: "Project") {
                    if let first = projects.first {
                        appendToInput(" #\(first.name)")
                    }
                }
                quickActionButton(icon: "timer", label: "30m") {
                    appendToInput(" 30m")
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Inline date picker
            if showDatePicker {
                DatePicker(
                    "Select date",
                    selection: $selectedDate,
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color.fdAccent)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onChange(of: selectedDate) { _, newDate in
                    // Format date into input
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    let dateStr = formatter.string(from: newDate)
                    let timeStr = timeFormatter.string(from: newDate)
                    appendToInput(" \(dateStr) \(timeStr)")
                    showDatePicker = false
                }
            }
        }
    }

    private func cyclePriority() {
        guard let current = manualPriority else {
            manualPriority = TaskPriority.none   // P4
            return
        }
        switch current {
        case .none:   manualPriority = .medium  // P3
        case .medium: manualPriority = .high    // P2
        case .high:   manualPriority = .urgent  // P1
        case .urgent: manualPriority = nil      // Clear
        }
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.fdMicro)
            }
            .foregroundStyle(Color.fdTextSecondary)
        }
    }

    // MARK: - Submit

    private func submitTask() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let parsed = parser.parse(inputText)

        // Find matching project
        var matchedProject: FDProject?
        if let projectName = parsed.projectName {
            matchedProject = projects.first { $0.name.localizedCaseInsensitiveContains(projectName) }
        }

        // Use manual priority if set, otherwise use parsed (default to P4, not P1)
        let finalPriority = manualPriority ?? (parsed.priority != TaskPriority.none ? parsed.priority : TaskPriority.none)

        taskService?.createTask(
            title: parsed.title,
            project: matchedProject,
            priority: finalPriority,
            dueDate: parsed.dueDate,
            scheduledTime: parsed.scheduledTime,
            estimatedMinutes: parsed.estimatedMinutes,
            labels: parsed.labels,
            recurrenceRule: parsed.recurrenceRule
        )

        inputText = ""
        parsedResult = nil
        manualPriority = nil
        onDismiss()
    }

    // MARK: - Helpers

    private func appendToInput(_ text: String) {
        inputText += text
        parsedResult = parser.parse(inputText)
    }

    private func hasAnyParsedData(_ p: ParsedTask) -> Bool {
        p.dueDate != nil || p.scheduledTime != nil || p.priority != .none ||
        p.projectName != nil || p.estimatedMinutes != nil ||
        p.recurrenceRule != nil || !p.labels.isEmpty
    }

    private func formatDateChip(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func projectColor(for name: String) -> Color {
        if let p = projects.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return Color(hex: p.colorHex)
        }
        return .fdAccent
    }

    private func durationText(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    private func recurrenceShort(_ rule: String) -> String {
        if rule.contains("DAILY") { return "Daily" }
        if rule.contains("BYDAY=MO,TU,WE,TH,FR") { return "Weekdays" }
        if rule.contains("BYDAY=MO") { return "Mon" }
        if rule.contains("BYDAY=TU") { return "Tue" }
        if rule.contains("BYDAY=WE") { return "Wed" }
        if rule.contains("BYDAY=TH") { return "Thu" }
        if rule.contains("BYDAY=FR") { return "Fri" }
        if rule.contains("WEEKLY") { return "Weekly" }
        if rule.contains("MONTHLY") { return "Monthly" }
        return "Repeats"
    }
}
