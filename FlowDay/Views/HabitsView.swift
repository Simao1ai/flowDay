// HabitsView.swift
// FlowDay

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query
    private var habitsRaw: [FDHabit]

    private var habits: [FDHabit] {
        habitsRaw.filter { $0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressSection
                    habitsListSection
                }
                .padding(20)
            }
            .background(Color.fdBackground)
            .navigationTitle("Habits")
            .toolbarTitleDisplayMode(.large)
        }
    }

    // MARK: - Progress Ring

    @ViewBuilder
    private var progressSection: some View {
        let dueToday = habits.filter(\.isDueToday)
        let completedCount = dueToday.filter(\.isCompletedToday).count
        let totalCount = dueToday.count

        if !dueToday.isEmpty {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.fdBorderLight, lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: progressFraction(completed: completedCount, total: totalCount))
                        .stroke(Color.fdAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text("today")
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func progressFraction(completed: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(completed) / CGFloat(total)
    }

    // MARK: - Habits List

    @ViewBuilder
    private var habitsListSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.system(size: 11))
            Text("Daily Habits")
        }
        .fdSectionHeader()

        if habits.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(habits.filter(\.isDueToday)) { habit in
                    habitRow(habit)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 44))
                .foregroundStyle(Color.fdAccent.opacity(0.4))
            Text("Build your routine")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("Add habits to track your daily streaks.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Habit Row

    private func habitRow(_ habit: FDHabit) -> some View {
        Button {
            let _ = habit.toggleToday()
            try? modelContext.save()
        } label: {
            habitRowContent(habit)
        }
        .buttonStyle(.plain)
    }

    private func habitRowContent(_ habit: FDHabit) -> some View {
        let habitColor = Color(hex: habit.colorHex)
        let completed = habit.isCompletedToday

        return HStack(spacing: 14) {
            habitIcon(habit)

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.fdBodySemibold)
                    .foregroundStyle(completed ? Color.fdTextMuted : Color.fdText)
                    .strikethrough(completed)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(habit.currentStreak) day streak")
                        .font(.fdMicro)
                }
                .foregroundStyle(habitColor)
            }

            Spacer()

            checkCircle(completed: completed, color: habitColor)
        }
        .padding(16)
        .background(completed ? habitColor.opacity(0.06) : Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(completed ? habitColor.opacity(0.2) : Color.fdBorderLight, lineWidth: 1)
        )
    }

    // Robust emoji display with SF Symbol fallback
    @ViewBuilder
    private func habitIcon(_ habit: FDHabit) -> some View {
        let emojiValid = !habit.emoji.isEmpty && habit.emoji != "✓" && habit.emoji.unicodeScalars.allSatisfy({ $0.properties.isEmoji && !$0.properties.isASCIIHexDigit })
        let habitColor = Color(hex: habit.colorHex)

        if emojiValid {
            Text(habit.emoji)
                .font(.title2)
        } else {
            // SF Symbol fallback based on habit name
            Image(systemName: sfSymbolForHabit(habit.name))
                .font(.system(size: 20))
                .foregroundStyle(habitColor)
                .frame(width: 36, height: 36)
                .background(habitColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func sfSymbolForHabit(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("meditat") || lower.contains("mindful") { return "brain.head.profile" }
        if lower.contains("exercis") || lower.contains("workout") || lower.contains("gym") { return "figure.run" }
        if lower.contains("read") || lower.contains("book") { return "book.fill" }
        if lower.contains("journal") || lower.contains("writ") { return "pencil.line" }
        if lower.contains("water") || lower.contains("drink") { return "drop.fill" }
        if lower.contains("sleep") || lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("walk") || lower.contains("step") { return "figure.walk" }
        if lower.contains("stretch") || lower.contains("yoga") { return "figure.flexibility" }
        if lower.contains("cook") || lower.contains("meal") { return "fork.knife" }
        if lower.contains("code") || lower.contains("program") { return "chevron.left.forwardslash.chevron.right" }
        return "flame.fill"
    }

    private func checkCircle(completed: Bool, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2.5)
                .frame(width: 28, height: 28)
            if completed {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
