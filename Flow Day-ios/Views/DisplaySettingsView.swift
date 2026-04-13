// DisplaySettingsView.swift
// FlowDay
//
// Todoist screenshot 4: Display settings with Layout (List/Board/Calendar),
// Completed Tasks toggle, Sort (Grouping, Sorting), Filter.
// FlowDay matches + adds energy-based sorting.

import SwiftUI

enum ViewLayout: String, CaseIterable {
    case list = "List"
    case board = "Board"
    case calendar = "Calendar"

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "rectangle.split.3x1"
        case .calendar: return "calendar"
        }
    }
}

enum TaskGrouping: String, CaseIterable {
    case none = "None"
    case project = "Project"
    case priority = "Priority"
    case dueDate = "Due Date"
    case energy = "Energy Level"
}

enum TaskSorting: String, CaseIterable {
    case smart = "Smart"
    case priority = "Priority"
    case dueDate = "Due Date"
    case alphabetical = "Alphabetical"
    case createdAt = "Date Added"
}

struct DisplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var layout: ViewLayout
    @Binding var showCompleted: Bool
    @Binding var grouping: TaskGrouping
    @Binding var sorting: TaskSorting

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Layout section
                    layoutSection

                    // Toggle section
                    toggleSection

                    // Sort section
                    sortSection
                }
                .padding(20)
            }
            .background(Color.fdBackground)
            .navigationTitle("Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.fdAccent)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Layout

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAYOUT")
                .fdSectionHeader()

            HStack(spacing: 12) {
                ForEach(ViewLayout.allCases, id: \.self) { option in
                    layoutButton(option)
                }
            }
        }
    }

    private func layoutButton(_ option: ViewLayout) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                layout = option
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.system(size: 22))
                    .frame(width: 56, height: 50)
                    .background(
                        layout == option
                            ? Color.fdAccent.opacity(0.12)
                            : Color.fdSurfaceHover
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(option.rawValue)
                    .font(.fdMicro)
                    .fontWeight(layout == option ? .bold : .medium)
            }
            .foregroundStyle(layout == option ? Color.fdAccent : Color.fdTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                layout == option
                    ? Color.fdAccent.opacity(0.04)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        layout == option ? Color.fdAccent.opacity(0.3) : Color.fdBorderLight,
                        lineWidth: layout == option ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toggles

    private var toggleSection: some View {
        VStack(spacing: 0) {
            toggleRow(
                icon: "checkmark.circle",
                label: "Completed Tasks",
                isOn: $showCompleted
            )
        }
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.fdTextSecondary)
                .frame(width: 24)

            Text(label)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            Toggle("", isOn: isOn)
                .tint(Color.fdAccent)
                .labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - Sort

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SORT")
                .fdSectionHeader()

            // Grouping
            sortRow(label: "Grouping") {
                Menu {
                    ForEach(TaskGrouping.allCases, id: \.self) { option in
                        Button {
                            grouping = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if grouping == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(grouping.rawValue)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }

            // Sorting
            sortRow(label: "Sorting") {
                Menu {
                    ForEach(TaskSorting.allCases, id: \.self) { option in
                        Button {
                            sorting = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sorting == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sorting.rawValue)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }
        }
    }

    private func sortRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: label == "Grouping" ? "square.grid.2x2" : "arrow.up.arrow.down")
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextSecondary)
                .frame(width: 24)

            Text(label)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            content()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}
