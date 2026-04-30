// FiltersLabelsView.swift
// FlowDay
//
// Filters & Labels management — matches Todoist's filter system
// but adds energy-based and AI-suggested filters unique to FlowDay.

import SwiftUI
import SwiftData

struct FiltersLabelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query
    private var allTasksRaw: [FDTask]

    private var allTasks: [FDTask] {
        allTasksRaw
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @State private var showAddLabel = false
    @State private var newLabelName = ""
    @State private var selectedLabelColor = "#D4713B"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    filtersSection
                    labelsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Filters & Labels")
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
            }
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "My Filters", count: filterItems.count)

            VStack(spacing: 0) {
                ForEach(filterItems, id: \.title) { item in
                    filterRow(item: item)
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func filterRow(item: FilterItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(item.color)
                    .frame(width: 28)

                Text(item.title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                Text("\(item.count)")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if item.title != filterItems.last?.title {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }

    private var filterItems: [FilterItem] {
        [
            FilterItem(title: "Urgent", icon: "flag.fill", color: .fdRed,
                       count: allTasks.filter { $0.priority == .urgent && !$0.isCompleted }.count),
            FilterItem(title: "High", icon: "flag.fill", color: Color(hex: "FB923C"),
                       count: allTasks.filter { $0.priority == .high && !$0.isCompleted }.count),
            FilterItem(title: "Medium", icon: "flag.fill", color: .fdYellow,
                       count: allTasks.filter { $0.priority == .medium && !$0.isCompleted }.count),
            FilterItem(title: "Low", icon: "flag", color: .fdTextMuted,
                       count: allTasks.filter { $0.priority == .none && !$0.isCompleted }.count),
            FilterItem(title: "Overdue", icon: "exclamationmark.circle.fill", color: .fdRed,
                       count: allTasks.filter { $0.isOverdue }.count),
            FilterItem(title: "No due date", icon: "calendar.badge.minus", color: .fdTextMuted,
                       count: allTasks.filter { $0.dueDate == nil && !$0.isCompleted }.count),
            FilterItem(title: "Has start date", icon: "calendar.badge.clock", color: .fdGreen,
                       count: allTasks.filter { $0.startDate != nil && !$0.isCompleted }.count),
            FilterItem(title: "AI Scheduled", icon: "sparkles", color: .fdAccent,
                       count: allTasks.filter { $0.aiSuggestedTime != nil && !$0.isCompleted }.count),
        ]
    }

    // MARK: - Labels Section

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "Labels", count: allLabels.count)
                Spacer()
                Button { showAddLabel = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fdAccent)
                        .frame(width: 30, height: 30)
                        .background(Color.fdAccentLight)
                        .clipShape(Circle())
                }
            }

            if allLabels.isEmpty {
                emptyLabelsCard
            } else {
                VStack(spacing: 0) {
                    ForEach(allLabels, id: \.self) { label in
                        labelRow(label: label)
                    }
                }
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
        .alert("New Label", isPresented: $showAddLabel) {
            TextField("Label name", text: $newLabelName)
            Button("Add") { addLabel() }
            Button("Cancel", role: .cancel) { newLabelName = "" }
        } message: {
            Text("Enter a name for the new label")
        }
    }

    private func labelRow(label: String) -> some View {
        let taskCount = allTasks.filter { $0.labels.contains(label) && !$0.isCompleted }.count
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 28)

                Text(label)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                Text("\(taskCount)")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if label != allLabels.last {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }

    private var emptyLabelsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 28))
                .foregroundStyle(Color.fdTextMuted)
            Text("No labels yet")
                .font(.fdBodyMedium)
                .foregroundStyle(Color.fdTextSecondary)
            Text("Labels help you categorize tasks across projects")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("\(count)")
                .font(.fdMicroBold)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
        }
    }

    private var allLabels: [String] {
        let labelArrays = allTasks.map { $0.labels }
        let flat = labelArrays.flatMap { $0 }
        return Array(Set(flat)).sorted()
    }

    private func addLabel() {
        guard !newLabelName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Labels are stored on tasks, so we just dismiss. The label will appear when assigned.
        newLabelName = ""
    }
}

// MARK: - Filter Item Model

private struct FilterItem {
    let title: String
    let icon: String
    let color: Color
    let count: Int
}
