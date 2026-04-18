// AIPlanView.swift
// FlowDay
//
// The AI scheduling sheet — shows suggested time slots for
// unscheduled tasks based on energy level and calendar gaps.

import SwiftUI
import SwiftData

struct AIPlanView: View {
    let taskService: TaskService?
    let energyLevel: EnergyLevel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query
    private var allTasksRaw: [FDTask]

    private var allTasks: [FDTask] {
        allTasksRaw.filter { !$0.isDeleted && !$0.isCompleted }
    }

    @State private var planResult: AIPlanResult?
    @State private var selectedSuggestions: Set<UUID> = []
    @State private var isApplying = false
    @State private var showSuccess = false

    private let planner = AIPlanner()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showSuccess {
                        successView
                    } else if let result = planResult {
                        planContent(result)
                    } else {
                        loadingView
                    }
                }
                .padding(20)
            }
            .background(Color.fdBackground)
            .navigationTitle("AI Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if planResult != nil && !showSuccess {
                        Button("Apply") {
                            applySelectedPlan()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.fdAccent)
                        .disabled(selectedSuggestions.isEmpty)
                    }
                }
            }
            .onAppear {
                generatePlan()
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.fdAccent)
            Text("Analyzing your tasks and energy...")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Plan Content

    private func planContent(_ result: AIPlanResult) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // AI Header
            aiHeader

            // Summary
            summaryCard(result.summary)

            // Tips
            if !result.tips.isEmpty {
                tipsSection(result.tips)
            }

            // Suggestions
            if !result.suggestions.isEmpty {
                suggestionsSection(result.suggestions)
            } else {
                emptyState
            }
        }
    }

    private var aiHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("FlowDay AI")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.fdGreen)
                        .frame(width: 6, height: 6)
                    Text("Analyzing your day")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
        }
    }

    private func summaryCard(_ summary: String) -> some View {
        Text(summary)
            .font(.fdBody)
            .foregroundStyle(Color.fdText)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.fdAccentLight, Color.fdPurpleLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 11))
                Text("Tips")
            }
            .fdSectionHeader()

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.fdAccent)
                        .padding(.top, 3)
                    Text(tip)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
            }
        }
    }

    // MARK: - Suggestions

    private func suggestionsSection(_ suggestions: [AIScheduleSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                    Text("Suggested Schedule")
                }
                .fdSectionHeader()

                Spacer()

                Button {
                    if selectedSuggestions.count == suggestions.count {
                        selectedSuggestions.removeAll()
                    } else {
                        selectedSuggestions = Set(suggestions.map(\.id))
                    }
                } label: {
                    Text(selectedSuggestions.count == suggestions.count ? "Deselect All" : "Select All")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdAccent)
                }
            }

            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
    }

    private func suggestionRow(_ suggestion: AIScheduleSuggestion) -> some View {
        let isSelected = selectedSuggestions.contains(suggestion.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedSuggestions.remove(suggestion.id)
                } else {
                    selectedSuggestions.insert(suggestion.id)
                }
            }
        } label: {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.fdAccent : Color.fdBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.fdAccent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.task.title)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                        .lineLimit(1)

                    Text(suggestion.reason)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                        .lineLimit(2)
                }

                Spacer()

                // Suggested time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(suggestion.suggestedTime.formatted(.dateTime.hour().minute()))
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                    if let mins = suggestion.task.estimatedMinutes {
                        Text("\(mins)m")
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }
            .padding(14)
            .background(isSelected ? Color.fdAccent.opacity(0.04) : Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.fdAccent.opacity(0.3) : Color.fdBorderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color.fdGreen.opacity(0.5))
            Text("All caught up!")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("No unscheduled tasks to plan.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.fdGreen)

            Text("Plan Applied!")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)

            Text("Your tasks have been scheduled. Check your timeline to see the updated plan.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("View Timeline")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.fdAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func generatePlan() {
        // Small delay for the loading animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let result = planner.generatePlan(
                tasks: allTasks,
                energyLevel: energyLevel
            )
            withAnimation(.easeIn(duration: 0.3)) {
                planResult = result
                // Select all by default
                selectedSuggestions = Set(result.suggestions.map(\.id))
            }
        }
    }

    private func applySelectedPlan() {
        guard let result = planResult else { return }
        let toApply = result.suggestions.filter { selectedSuggestions.contains($0.id) }

        isApplying = true
        planner.applyPlan(toApply, using: modelContext)

        withAnimation(.easeInOut(duration: 0.4)) {
            showSuccess = true
        }
    }
}
