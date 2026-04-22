// DayRecapView.swift
// FlowDay

import SwiftUI
import SwiftData

struct DayRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allTasksRaw: [FDTask]
    @Query private var allHabitsRaw: [FDHabit]
    @Query private var energyLogsRaw: [FDEnergyLog]

    @State private var service = DayRecapService()

    private var completedToday: [FDTask] {
        allTasksRaw.filter { task in
            guard let at = task.completedAt else { return false }
            return Calendar.current.isDateInToday(at)
        }
        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var activeHabits: [FDHabit] { allHabitsRaw.filter { $0.isActive } }
    private var habitsCompletedToday: Int { activeHabits.filter { $0.isCompletedToday }.count }

    private var todayEnergy: EnergyLevel? {
        energyLogsRaw
            .filter { Calendar.current.isDateInToday($0.date) }
            .first?.level
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    recapCard
                    if !completedToday.isEmpty {
                        completedTasksList
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color.fdBackground)
            .navigationTitle("Day Recap")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fdTextSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.fdSurfaceHover)
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await generateRecap() }
                    } label: {
                        if service.isLoading {
                            ProgressView().tint(Color.fdAccent).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.fdAccent)
                        }
                    }
                    .disabled(service.isLoading)
                }
            }
            .task { await generateRecap() }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "checkmark.circle.fill",
                value: "\(completedToday.count)",
                label: "Done",
                color: .fdGreen
            )
            statCard(
                icon: "flame.fill",
                value: "\(habitsCompletedToday)/\(activeHabits.count)",
                label: "Habits",
                color: .fdYellow
            )
            statCard(
                icon: "bolt.fill",
                value: todayEnergy?.rawValue.capitalized ?? "—",
                label: "Energy",
                color: .fdAccent
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
    }

    // MARK: - AI recap card

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fdAccent)
                Text("AI Recap")
                    .font(.fdCaptionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Group {
                if service.isLoading {
                    HStack(spacing: 12) {
                        ProgressView().tint(Color.fdAccent)
                        Text("Generating your recap…")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
                } else if let text = service.recap {
                    Text(text)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .lineSpacing(5)
                } else if let err = service.error {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.fdYellow)
                        Text(err)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await generateRecap() }
                        }
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    Text("Tap the refresh button to generate today's recap.")
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextMuted)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
    }

    // MARK: - Completed tasks list

    private var completedTasksList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11))
                Text("Completed Today")
            }
            .fdSectionHeader()

            ForEach(completedToday.prefix(15)) { task in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.fdGreen)
                    Text(task.title)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextMuted)
                        .strikethrough(color: Color.fdTextMuted)
                        .lineLimit(1)
                    Spacer()
                }
            }

            if completedToday.count > 15 {
                Text("+ \(completedToday.count - 15) more")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.leading, 24)
            }
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
    }

    // MARK: - Helpers

    private func generateRecap() async {
        await service.generateRecap(
            completedTasks: completedToday,
            habitsCompleted: habitsCompletedToday,
            habitsTotal: activeHabits.count,
            energyLevel: todayEnergy
        )
    }
}
