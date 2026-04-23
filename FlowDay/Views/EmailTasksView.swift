// EmailTasksView.swift
// FlowDay — Review AI-suggested tasks extracted from inbox emails

import SwiftUI
import SwiftData

struct EmailTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var suggestions: [EmailTaskSuggestion]

    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionList
                }
            }
            .background(Color.fdBackground)
            .navigationTitle("Email Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdAccent)
                }
            }
        }
    }

    // MARK: - List

    private var suggestionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                hintRow

                ForEach(suggestions) { suggestion in
                    suggestionRow(suggestion)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.25), value: suggestions.map(\.id))
        }
    }

    private var hintRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.fdGreen)
            Text("Swipe right to add · Swipe left to dismiss")
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func suggestionRow(_ suggestion: EmailTaskSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                priorityDot(suggestion.suggestedPriority)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.suggestedTitle)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)

                    HStack(spacing: 6) {
                        Image(systemName: "envelope")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fdTextMuted)
                        Text(suggestion.emailFrom.isEmpty ? suggestion.emailSubject : suggestion.emailFrom)
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                            .lineLimit(1)
                    }

                    if !suggestion.suggestedNotes.isEmpty {
                        Text(suggestion.suggestedNotes)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextSecondary)
                            .lineLimit(2)
                    }

                    if let due = suggestion.suggestedDueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.fdAccent)
                            Text(due.formatted(date: .abbreviated, time: .omitted))
                                .font(.fdMicro)
                                .foregroundStyle(Color.fdAccent)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 44)
        }
        .background(Color.fdSurface)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                approve(suggestion)
            } label: {
                Label("Add Task", systemImage: "plus.circle.fill")
            }
            .tint(Color.fdGreen)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dismiss(suggestion)
            } label: {
                Label("Dismiss", systemImage: "xmark.circle.fill")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.fdTextMuted)
            Text("All caught up")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Text("No actionable emails found in your inbox.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Actions

    private func approve(_ suggestion: EmailTaskSuggestion) {
        let task = FDTask(
            title: suggestion.suggestedTitle,
            notes: suggestion.suggestedNotes,
            dueDate: suggestion.suggestedDueDate,
            priority: suggestion.suggestedPriority
        )
        modelContext.insert(task)
        try? modelContext.save()
        Task { await SupabaseService.shared.syncTask(task) }
        Haptics.success()
        remove(suggestion)
    }

    private func dismiss(_ suggestion: EmailTaskSuggestion) {
        Haptics.pick()
        remove(suggestion)
    }

    private func remove(_ suggestion: EmailTaskSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        if suggestions.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() }
        }
    }

    // MARK: - Helpers

    private func priorityDot(_ priority: TaskPriority) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 8, height: 8)
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: Color.fdRed
        case .high:   Color.fdYellow
        case .medium: Color.fdBlue
        case .none:   Color.fdTextMuted
        }
    }
}
