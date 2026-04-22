// DayRecapView.swift
// FlowDay
// AI-powered end-of-day recap: stats + a 3-sentence motivational summary.
// Accessible from TodayView toolbar and Settings > Productivity.

import SwiftUI
import SwiftData

struct DayRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // Plain @Query — no predicates (crash on iOS 26.x). Filtered in computed props.
    @Query private var allTasksRaw: [FDTask]
    @Query private var allHabitsRaw: [FDHabit]

    private var tasks: [FDTask] { allTasksRaw.filter { !$0.isDeleted } }
    private var habits: [FDHabit] { allHabitsRaw.filter(\.isActive) }

    @State private var recapService = DayRecapService()

    private var completedToday: [FDTask] {
        tasks.filter {
            $0.isCompleted && Calendar.current.isDateInToday($0.completedAt ?? .distantPast)
        }
    }
    private var dueHabitsToday: [FDHabit] { habits.filter(\.isDueToday) }
    private var doneHabitsToday: [FDHabit] { habits.filter(\.isCompletedToday) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsSection
                    aiSummarySection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.fdBackground)
            .navigationTitle("Day Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }
            .task {
                await recapService.generateRecap(
                    tasks: tasks,
                    habits: habits,
                    energy: appState.todayEnergy
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.fdAccent, .fdPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("End of Day")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RecapStatCard(
                    value: "\(completedToday.count)",
                    label: "Tasks Done",
                    icon: "checkmark.circle.fill",
                    color: .fdGreen
                )
                RecapStatCard(
                    value: "\(doneHabitsToday.count)/\(dueHabitsToday.count)",
                    label: "Habits",
                    icon: "flame.fill",
                    color: .fdAccent
                )
                if let energy = appState.todayEnergy {
                    RecapStatCard(
                        value: energy.emoji,
                        label: energy.label,
                        icon: "bolt.fill",
                        color: .fdYellow
                    )
                }
            }

            if !completedToday.isEmpty {
                completedTasksList
            }
        }
    }

    private var completedTasksList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11))
                Text("Completed today")
            }
            .fdSectionHeader()

            VStack(spacing: 6) {
                ForEach(completedToday.prefix(5)) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.fdGreen)
                        Text(task.title)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdText)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if completedToday.count > 5 {
                    Text("+ \(completedToday.count - 5) more")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                        .padding(.leading, 14)
                }
            }
        }
    }

    // MARK: - AI summary

    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text("AI Reflection")
            }
            .fdSectionHeader()

            Group {
                if recapService.isLoading {
                    loadingCard
                } else if let summary = recapService.summary {
                    summaryCard(summary)
                } else if let errMsg = recapService.error {
                    errorCard(errMsg)
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.fdAccent)
            Text("Generating your recap…")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
                .lineSpacing(4)

            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdAccent)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.fdAccentLight, Color.fdPurpleLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text("Couldn't generate recap")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
            Text(message)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await recapService.generateRecap(
                        tasks: tasks,
                        habits: habits,
                        energy: appState.todayEnergy
                    )
                }
            }
            .font(.fdCaptionBold)
            .foregroundStyle(Color.fdAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Stat card

struct RecapStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorderLight, lineWidth: 1)
        )
    }
}
