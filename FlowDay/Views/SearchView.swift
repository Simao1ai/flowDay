// SearchView.swift
// FlowDay
//
// Global search across tasks, projects, and labels.
// Provides instant results as the user types.

import SwiftUI
import SwiftData

struct SearchView: View {
    let taskService: TaskService?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query
    private var allTasksRaw: [FDTask]

    private var allTasks: [FDTask] {
        allTasksRaw
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @Query
    private var allProjectsRaw: [FDProject]

    private var allProjects: [FDProject] {
        allProjectsRaw.sorted { $0.sortOrder < $1.sortOrder }
    }

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTask: FDTask?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsContent
            }
            .background(Color.fdBackground)
            .navigationBarHidden(true)
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, taskService: taskService)
            }
        }
        .onAppear { isSearchFocused = true }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fdText)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fdTextMuted)

                TextField("Search tasks, projects, labels...", text: $searchText)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.fdSurfaceHover)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        if searchText.isEmpty {
            recentAndSuggestions
        } else {
            searchResults
        }
    }

    private var recentAndSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                quickFilters
                recentTasksSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var quickFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK FILTERS")
                .modifier(FDSectionHeader())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(icon: "exclamationmark.triangle", label: "Overdue", color: .fdRed)
                    filterChip(icon: "flag.fill", label: "Priority 1", color: .fdRed)
                    filterChip(icon: "calendar.badge.minus", label: "No date", color: .fdTextMuted)
                    filterChip(icon: "sparkles", label: "AI Scheduled", color: .fdAccent)
                    filterChip(icon: "calendar.badge.clock", label: "Has start date", color: .fdGreen)
                }
            }
        }
    }

    private func filterChip(icon: String, label: String, color: Color) -> some View {
        Button {
            searchText = label
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.fdCaption)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT TASKS")
                .modifier(FDSectionHeader())

            VStack(spacing: 0) {
                ForEach(recentTasks) { task in
                    taskResultRow(task: task)
                    if task.id != recentTasks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !matchingProjects.isEmpty {
                    projectResultsSection
                }
                if !matchingTasks.isEmpty {
                    taskResultsSection
                }
                if matchingProjects.isEmpty && matchingTasks.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var projectResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROJECTS")
                .modifier(FDSectionHeader())

            VStack(spacing: 0) {
                ForEach(matchingProjects) { project in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 10, height: 10)
                            .frame(width: 28)

                        Text(project.name)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)

                        Spacer()

                        Text("\(project.activeTasks.count) tasks")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if project.id != matchingProjects.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private var taskResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TASKS (\(matchingTasks.count))")
                .modifier(FDSectionHeader())

            VStack(spacing: 0) {
                ForEach(matchingTasks) { task in
                    taskResultRow(task: task)
                    if task.id != matchingTasks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func taskResultRow(task: FDTask) -> some View {
        Button {
            selectedTask = task
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(task.priority.color, lineWidth: 2)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .lineLimit(1)

                    taskMeta(task: task)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func taskMeta(task: FDTask) -> some View {
        HStack(spacing: 6) {
            if let project = task.project {
                Text(project.name)
                    .font(.fdMicro)
                    .foregroundStyle(Color(hex: project.colorHex))
            }
            if let due = task.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(due, format: .dateTime.month(.abbreviated).day())
                        .font(.fdMicro)
                }
                .foregroundStyle(task.isOverdue ? Color.fdRed : Color.fdTextMuted)
            }
            if task.isCompleted {
                Text("Done")
                    .font(.fdMicroBold)
                    .foregroundStyle(Color.fdGreen)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.fdTextMuted.opacity(0.5))
            Text("No results for \"\(searchText)\"")
                .font(.fdBodyMedium)
                .foregroundStyle(Color.fdTextSecondary)
            Text("Try a different search term")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data Helpers

    private var recentTasks: [FDTask] {
        Array(allTasks.filter { !$0.isCompleted }.prefix(5))
    }

    private var matchingTasks: [FDTask] {
        let query = searchText.lowercased()
        return allTasks.filter { task in
            task.title.lowercased().contains(query) ||
            task.notes.lowercased().contains(query) ||
            task.labels.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private var matchingProjects: [FDProject] {
        let query = searchText.lowercased()
        return allProjects.filter { $0.name.lowercased().contains(query) }
    }
}
