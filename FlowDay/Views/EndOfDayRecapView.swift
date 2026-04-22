// EndOfDayRecapView.swift
// FlowDay — Wave 4b
//
// Evening summary: tasks completed today, habit streak, AI motivational review.

import SwiftUI
import SwiftData

// MARK: - Recap Service

@Observable
final class EndOfDayRecapService {
    var recapText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    @MainActor
    func generate(completedTasks: [FDTask], habitsCompleted: Int, totalHabits: Int) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let taskLines = completedTasks.prefix(10)
            .map { "• \($0.title)" }
            .joined(separator: "\n")

        let prompt = """
        Here is today's productivity summary:

        Tasks completed (\(completedTasks.count) total):
        \(taskLines.isEmpty ? "None completed today" : taskLines)

        Habits: \(habitsCompleted) of \(totalHabits) completed today.

        Write a warm, specific, 2–3 sentence end-of-day review. \
        Mention something concrete from the tasks if available. \
        Be genuinely encouraging without being generic.
        """

        do {
            recapText = try await ClaudeClient.shared.chat(
                feature: .endOfDayRecap,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.8,
                maxTokens: 200
            )
        } catch {
            errorMessage = error.localizedDescription
            // Provide a graceful offline fallback
            recapText = completedTasks.isEmpty
                ? "Every day is a fresh start. Tomorrow is yours to shape."
                : "You showed up and got things done — that's what counts. Rest well and go again tomorrow."
        }

        isLoading = false
    }
}

// MARK: - View

struct EndOfDayRecapView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var allTasksRaw: [FDTask]
    @Query private var allHabitsRaw: [FDHabit]
    @Query private var allHabitLogsRaw: [FDHabitLog]

    @State private var recapService = EndOfDayRecapService()

    // MARK: Computed data

    private var completedToday: [FDTask] {
        allTasksRaw.filter { task in
            guard task.isCompleted, let at = task.completedAt else { return false }
            return Calendar.current.isDateInToday(at)
        }
    }

    private var activeHabits: [FDHabit] {
        allHabitsRaw.filter { $0.isActive }
    }

    private var habitsCompletedToday: Int {
        allHabitLogsRaw.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    statsRow
                    aiSection
                    if !completedToday.isEmpty {
                        completedTasksSection
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.fdBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await recapService.generate(
                                completedTasks: completedToday,
                                habitsCompleted: habitsCompletedToday,
                                totalHabits: activeHabits.count
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.fdAccent)
                    }
                    .disabled(recapService.isLoading)
                }
            }
        }
        .task {
            await recapService.generate(
                completedTasks: completedToday,
                habitsCompleted: habitsCompletedToday,
                totalHabits: activeHabits.count
            )
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("End of Day")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.horizontal, 20)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(completedToday.count)",
                label: "Tasks Done",
                icon: "checkmark.circle.fill",
                color: .fdGreen
            )
            statCard(
                value: "\(habitsCompletedToday)/\(activeHabits.count)",
                label: "Habits",
                icon: "flame.fill",
                color: .fdYellow
            )
        }
        .padding(.horizontal, 20)
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fdAccent)
                Text("AI Review")
            }
            .fdSectionHeader()

            Group {
                if recapService.isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.8)
                        Text("Reflecting on your day…")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if !recapService.recapText.isEmpty {
                    Text(recapService.recapText)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.fdAccent.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                Text("Completed Today")
            }
            .fdSectionHeader()

            VStack(spacing: 0) {
                ForEach(completedToday) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.fdGreen)
                        Text(task.title)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdText)
                            .strikethrough(true, color: Color.fdTextMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if task.id != completedToday.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fdBorderLight, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Components

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(value)
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
    }
}
