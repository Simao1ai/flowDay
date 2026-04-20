// AIAssistantService.swift
// FlowDay
//
// Chat controller for Flow AI. Owns the message list, routes user prompts
// to intent-specific handlers (plan day, create task, break down goal),
// and reaches into SwiftData for the user's real context so the assistant
// grounds its replies in the user's actual tasks, projects, and energy.

import Foundation
import SwiftData
import SwiftUI

@Observable @MainActor
final class AIAssistantService {
    var messages: [AIMessage] = []
    var isTyping: Bool = false
    var showUpgradePrompt: Bool = false

    /// The pending AI task suggestion waiting for user confirmation
    var pendingTaskSuggestion: AITaskSuggestion?

    /// ModelContext for reading/writing SwiftData — set by the view
    var modelContext: ModelContext?

    init() {
        let welcomeMessage = AIMessage(
            content: "Hi! I'm Flow, your AI productivity assistant. I can plan your day around your energy, create tasks from natural language, break down big goals, and more. What would you like to do?",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: "")),
                AISuggestion(text: "Break down a goal", icon: "list.bullet.indent", action: .breakdownGoal(goal: "")),
                AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
            ]
        )
        self.messages = [welcomeMessage]
    }

    // MARK: - Data Queries

    // All fetches use plain FetchDescriptor — predicates/sorts crash on iOS 26.x
    private func fetchTodayTasks() -> [FDTask] {
        guard let context = modelContext else { return [] }
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            return all.filter { !$0.isDeleted && !$0.isCompleted }
                .sorted { ($0.priority.rawValue) > ($1.priority.rawValue) }
        } catch {
            return []
        }
    }

    private func fetchProjects() -> [FDProject] {
        guard let context = modelContext else { return [] }
        do {
            let all = try context.fetch(FetchDescriptor<FDProject>())
            return all.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        } catch {
            return []
        }
    }

    private func fetchTodayEnergy() -> EnergyLevel {
        guard let context = modelContext else { return .normal }
        let today = Calendar.current.startOfDay(for: .now)
        do {
            let all = try context.fetch(FetchDescriptor<FDEnergyLog>())
            return all.filter { $0.date >= today }
                .sorted { $0.date > $1.date }
                .first?.level ?? .normal
        } catch {
            return .normal
        }
    }

    private func fetchCompletedTodayCount() -> Int {
        guard let context = modelContext else { return 0 }
        let today = Calendar.current.startOfDay(for: .now)
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            return all.filter { $0.isCompleted && !$0.isDeleted && $0.completedAt != nil && $0.completedAt! >= today }.count
        } catch {
            return 0
        }
    }

    /// Build a context summary of the user's real data for the system prompt
    private func buildUserContext() -> String {
        let tasks = fetchTodayTasks()
        let projects = fetchProjects()
        let energy = fetchTodayEnergy()
        let completedToday = fetchCompletedTodayCount()

        let taskSummary = tasks.prefix(15).map { task in
            var desc = "- \(task.title) [P\(task.priority.rawValue)]"
            if let mins = task.estimatedMinutes { desc += " ~\(mins)min" }
            if let due = task.dueDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .short
                desc += " due \(fmt.string(from: due))"
            }
            if let proj = task.project { desc += " in \(proj.name)" }
            return desc
        }.joined(separator: "\n")

        let projectSummary = projects.map { "\($0.name) (\($0.activeTasks.count) active)" }.joined(separator: ", ")

        return """
        USER CONTEXT (real data):
        Energy: \(energy.label)
        Pending tasks: \(tasks.count) (\(completedToday) completed today)
        \(taskSummary.isEmpty ? "No pending tasks" : taskSummary)
        Projects: \(projectSummary.isEmpty ? "None" : projectSummary)
        """
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = AIMessage(content: text, isUser: true)
        messages.append(userMessage)
        isTyping = true

        Task {
            await generateAIResponse(for: text)
        }
    }

    // MARK: - Response Generation

    private func generateAIResponse(for userMessage: String) async {
        defer { isTyping = false }

        guard SubscriptionManager.shared.hasRemainingUsage(.aiChat) else {
            showUpgradePrompt = true
            await appendMessage(AIMessage(
                content: "You've reached your daily AI chat limit. Upgrade to Pro for unlimited access!",
                isUser: false
            ))
            return
        }

        let lower = userMessage.lowercased()
        var response: AIMessage?

        if lower.contains("plan") && (lower.contains("day") || lower.contains("schedule") || lower.contains("today")) {
            response = await handlePlanDay()
        } else if lower.contains("break") && (lower.contains("down") || lower.contains("goal") || lower.contains("steps")) {
            response = await handleBreakdownGoal(userMessage)
        } else if lower.contains("create") || lower.contains("add task") || lower.contains("new task") || lower.contains("remind me") {
            response = await handleCreateTask(userMessage: userMessage)
        } else if lower.contains("complete") || lower.contains("done") || lower.contains("finish") {
            response = await handleCompleteTask(userMessage: userMessage)
        } else if lower.contains("how am i") || lower.contains("productivity") || lower.contains("progress") || lower.contains("stats") {
            response = handleProductivityCheck()
        } else {
            response = await handleGeneralChat(userMessage: userMessage)
        }

        if let response {
            await appendMessage(response)
            SubscriptionManager.shared.incrementUsage(.aiChat)
        }
    }

    @MainActor
    private func appendMessage(_ message: AIMessage) {
        messages.append(message)
    }

    // MARK: - Plan Day (with real data)

    private func handlePlanDay() async -> AIMessage {
        let tasks = fetchTodayTasks()
        let energy = fetchTodayEnergy()

        guard !tasks.isEmpty else {
            return AIMessage(
                content: "You don't have any pending tasks right now. Want me to help you create some?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: "")),
                    AISuggestion(text: "Break down a goal", icon: "list.bullet.indent", action: .breakdownGoal(goal: ""))
                ]
            )
        }

        let calendarService = CalendarService()
        calendarService.fetchTodayEvents()
        let events = calendarService.todayEvents.map { "\($0.title ?? "Event") at \(DateFormatter.localizedString(from: $0.startDate, dateStyle: .none, timeStyle: .short))" }
        let freeSlots = calendarService.freeSlots(for: .now)

        do {
            let plan = try await AIFeatureService.shared.generateSmartPlan(
                tasks: Array(tasks.prefix(20)),
                energyLevel: energy,
                calendarEvents: events,
                freeSlots: freeSlots.map { (start: $0.start, end: Calendar.current.date(byAdding: .minute, value: $0.durationMinutes, to: $0.start) ?? $0.start) },
                history: recentConversationHistory()
            )

            let taskList = plan.scheduledTasks.map { "• \($0.taskTitle) → \($0.suggestedTime)" }.joined(separator: "\n")
            let tipsText = plan.tips.isEmpty ? "" : "\n\nTips: " + plan.tips.joined(separator: " • ")

            return AIMessage(
                content: "Here's your optimized plan based on your \(energy.label.lowercased()) energy:\n\n\(plan.summary)\n\n\(taskList)\(tipsText)",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: "")),
                    AISuggestion(text: "Break down a goal", icon: "list.bullet.indent", action: .breakdownGoal(goal: ""))
                ]
            )
        } catch {
            let topTasks = tasks.prefix(5).map { "• \($0.title) [\($0.priority.label)]" }.joined(separator: "\n")
            return AIMessage(
                content: "I couldn't generate an AI plan right now, but here are your top priorities at \(energy.label.lowercased()) energy:\n\n\(topTasks)\n\nFocus on P1/P2 tasks first, then work through the rest.",
                isUser: false
            )
        }
    }

    // MARK: - Create Task (AI-parsed, then confirm)

    private func handleCreateTask(userMessage: String) async -> AIMessage {
        do {
            let suggestion = try await AIFeatureService.shared.parseTaskWithAI(
                input: userMessage,
                history: recentConversationHistory()
            )
            pendingTaskSuggestion = suggestion

            var details = "📝 \(suggestion.title)\n"
            details += "Priority: P\(suggestion.priority)"
            if let mins = suggestion.estimatedMinutes { details += " • ~\(mins) min" }
            if let project = suggestion.project { details += "\nProject: \(project)" }
            if let due = suggestion.dueDate { details += "\nDue: \(due)" }
            if !suggestion.labels.isEmpty { details += "\nLabels: \(suggestion.labels.joined(separator: ", "))" }

            return AIMessage(
                content: "I parsed your task:\n\n\(details)\n\nShould I add it?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Add it", icon: "checkmark.circle.fill", action: .confirmTask),
                    AISuggestion(text: "Change something", icon: "pencil", action: .createTask(title: suggestion.title))
                ],
                pendingTask: suggestion
            )
        } catch {
            return AIMessage(
                content: "Tell me about the task — what's it called, when is it due, and how important is it?",
                isUser: false
            )
        }
    }

    // MARK: - Confirm & Save Task to SwiftData

    func confirmPendingTask() {
        guard let suggestion = pendingTaskSuggestion, let context = modelContext else { return }

        let priority = TaskPriority(rawValue: suggestion.priority) ?? .medium

        var dueDate: Date? = nil
        if let dueDateString = suggestion.dueDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            dueDate = formatter.date(from: dueDateString)
        }

        var project: FDProject? = nil
        if let projectName = suggestion.project {
            let projects = fetchProjects()
            project = projects.first { $0.name.lowercased() == projectName.lowercased() }
        }

        let task = FDTask(
            title: suggestion.title,
            dueDate: dueDate,
            estimatedMinutes: suggestion.estimatedMinutes,
            priority: priority,
            labels: suggestion.labels,
            project: project
        )

        context.insert(task)
        try? context.save()

        pendingTaskSuggestion = nil

        let projectNote = project.map { " in \($0.name)" } ?? ""
        messages.append(AIMessage(
            content: "Done! Created \"\(suggestion.title)\"\(projectNote). Anything else?",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Create another", icon: "plus.circle", action: .createTask(title: "")),
                AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay)
            ]
        ))
    }

    // MARK: - Complete Task by Name

    private func handleCompleteTask(userMessage: String) async -> AIMessage {
        let tasks = fetchTodayTasks()
        let lower = userMessage.lowercased()

        if let match = tasks.first(where: { lower.contains($0.title.lowercased()) }) {
            return AIMessage(
                content: "Mark \"\(match.title)\" as complete?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Yes, complete it", icon: "checkmark.circle.fill", action: .completeTask(id: match.id)),
                    AISuggestion(text: "No, cancel", icon: "xmark", action: .showProductivity)
                ]
            )
        }

        let taskList = tasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        return AIMessage(
            content: "Which task did you complete? Here are your active ones:\n\n\(taskList)",
            isUser: false
        )
    }

    func completeTask(id: UUID) {
        guard let context = modelContext else { return }
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            if let task = all.first(where: { $0.id == id }) {
                task.complete()
                try? context.save()
                messages.append(AIMessage(
                    content: "Marked \"\(task.title)\" as complete! Nice work 💪",
                    isUser: false,
                    suggestions: [
                        AISuggestion(text: "What's next?", icon: "arrow.right", action: .planDay),
                        AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
                    ]
                ))
            }
        } catch {
            // Silently fail and don't update UI
        }
    }

    // MARK: - Break Down Goal

    private func handleBreakdownGoal(_ userMessage: String) async -> AIMessage {
        let goal = userMessage
            .replacingOccurrences(of: "break down", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "break this down", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "into steps", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !goal.isEmpty else {
            return AIMessage(
                content: "What's the goal or project you'd like me to break down into tasks?",
                isUser: false
            )
        }

        do {
            let breakdown = try await AIFeatureService.shared.breakdownTask(
                goal: goal,
                history: recentConversationHistory()
            )

            let subtaskList = breakdown.subtasks.enumerated().map { i, item in
                "\(i + 1). \(item.title) [P\(item.priority), ~\(item.estimatedMinutes)min]"
            }.joined(separator: "\n")

            let projectNote = breakdown.projectSuggestion != nil ? "\nSuggested project: \(breakdown.projectSuggestion!)" : ""

            return AIMessage(
                content: "Here's the breakdown for \"\(breakdown.originalGoal)\":\n\n\(subtaskList)\(projectNote)\n\nWant me to create all of these as tasks?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Create all tasks", icon: "checkmark.circle.fill", action: .confirmTask),
                    AISuggestion(text: "Just the first 3", icon: "line.3.horizontal.decrease", action: .createTask(title: breakdown.subtasks.prefix(3).map(\.title).joined(separator: ", ")))
                ]
            )
        } catch {
            return AIMessage(
                content: "I couldn't break that down right now. Try rephrasing your goal, or create a task directly.",
                isUser: false
            )
        }
    }

    // MARK: - Productivity Check (real data)

    private func handleProductivityCheck() -> AIMessage {
        let tasks = fetchTodayTasks()
        let completedToday = fetchCompletedTodayCount()
        let energy = fetchTodayEnergy()
        let totalPending = tasks.count

        let overdue = tasks.filter(\.isOverdue).count
        let overdueNote = overdue > 0 ? "\n⚠️ \(overdue) overdue task\(overdue == 1 ? "" : "s") — consider rescheduling." : ""

        return AIMessage(
            content: "Here's your snapshot:\n\n✅ Completed today: \(completedToday)\n📋 Pending: \(totalPending)\n⚡ Energy: \(energy.label)\(overdueNote)\n\n\(completedToday > 3 ? "Great momentum — keep it up!" : completedToday > 0 ? "Good start! Pick one more task to tackle." : "Let's get started — want me to plan your day?")",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))
            ]
        )
    }

    // MARK: - General Chat (context-rich, server-cached)

    /// All chat now goes through the Supabase Edge Function so it benefits
    /// from the same prompt caching and server-managed Anthropic key as the
    /// structured features. The user's live SwiftData snapshot is prepended
    /// as a synthetic "user" turn — that keeps the cached system prompt
    /// stable while still giving the model fresh context every call.
    private func handleGeneralChat(userMessage: String) async -> AIMessage {
        let context = buildUserContext()
        let history = recentConversationHistory()

        // Prepend a context-only message so Claude sees the user's current
        // state without having to refetch it.
        var messages: [LLMMessage] = [
            LLMMessage(
                role: .user,
                content: "Context for this conversation (do not respond to this message directly):\n\n\(context)"
            ),
            LLMMessage(
                role: .assistant,
                content: "Got it. I'll factor that in."
            )
        ]
        messages.append(contentsOf: history)

        do {
            let response = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: messages,
                temperature: 0.7,
                maxTokens: 400
            )
            return AIMessage(content: response, isUser: false)
        } catch {
            return AIMessage(
                content: "I'm having trouble connecting right now. Try asking me to plan your day or create a task — those work offline too!",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))
                ]
            )
        }
    }

    // MARK: - Conversation History

    /// Last N turns of the on-screen chat, mapped to LLMMessage so feature
    /// calls can give Claude the same context the user is looking at.
    /// Skips the welcome message (which is just a static greeting).
    private func recentConversationHistory(limit: Int = 8) -> [LLMMessage] {
        // Drop the first message if it's our welcome greeting from init()
        let trimmed = messages.dropFirst()
        return trimmed.suffix(limit).map { msg in
            LLMMessage(role: msg.isUser ? .user : .assistant, content: msg.content)
        }
    }

    // MARK: - Handle Suggestion Taps

    func handleSuggestion(_ suggestion: AISuggestion) {
        Haptics.tap()
        switch suggestion.action {
        case .confirmTask:
            confirmPendingTask()
        case .completeTask(let id):
            completeTask(id: id)
        case .createTask(let title):
            sendMessage(title.isEmpty ? "Create a task" : "Create a task: \(title)")
        case .planDay:
            sendMessage("Plan my day")
        case .breakdownGoal(let goal):
            sendMessage(goal.isEmpty ? "Break down a goal" : "Break down \(goal) into steps")
        case .generateTemplate(let category):
            sendMessage("Generate a \(category) template")
        case .suggestBreak:
            sendMessage("I need a break")
        case .showProductivity:
            sendMessage("How am I doing today?")
        }
    }
}
