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

    // MARK: - Clear Chat

    func clearChat() {
        messages = [
            AIMessage(
                content: "Hi! I'm Flow, your AI productivity assistant. I can plan your day around your energy, create tasks from natural language, break down big goals, and more. What would you like to do?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: "")),
                    AISuggestion(text: "Break down a goal", icon: "list.bullet.indent", action: .breakdownGoal(goal: "")),
                    AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
                ]
            )
        ]
        isTyping = false
        showUpgradePrompt = false
        pendingTaskSuggestion = nil
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

        guard ProAccessManager.shared.canUseAI else {
            showUpgradePrompt = true
            await appendMessage(AIMessage(
                content: "You've used all \(ProAccessManager.shared.freeAILimit) free AI calls for today. Upgrade to Pro for unlimited access!",
                isUser: false
            ))
            return
        }

        let lower = userMessage.lowercased()
        var response: AIMessage?

        // Structured intents (handled locally with SwiftData)
        if lower.contains("plan") && (lower.contains("day") || lower.contains("schedule") || lower.contains("today")) {
            response = await handlePlanDay()
        } else if lower.contains("break") && (lower.contains("down") || lower.contains("goal") || lower.contains("steps")) {
            response = await handleBreakdownGoal(userMessage)
        } else if lower.contains("create") || lower.contains("add task") || lower.contains("new task") || lower.contains("remind me") {
            response = await handleCreateTask(userMessage: userMessage)
        } else if lower.contains("how am i") || lower.contains("productivity") || lower.contains("progress") || lower.contains("stats") {
            response = handleProductivityCheck()

        // Natural language task management — route to AI with action-aware system prompt
        } else if isTaskManagementIntent(lower) {
            response = await handleNLTaskCommand(userMessage: userMessage)
        } else {
            response = await handleGeneralChat(userMessage: userMessage)
        }

        if let response {
            await appendMessage(response)
            ProAccessManager.shared.recordAICall()
        }
    }

    // MARK: - Intent Detection

    private func isTaskManagementIntent(_ lower: String) -> Bool {
        let rescheduleKeywords = ["move", "reschedule", "push", "change the date", "change date"]
        let deleteKeywords = ["delete", "remove", "get rid of"]
        let priorityKeywords = ["set priority", "make it priority", "change priority", "priority 1", "priority 2", "p1", "p2", "p3"]
        let queryKeywords = ["what did i work on", "what have i done", "show me", "find", "list", "how many tasks", "count"]

        return rescheduleKeywords.contains(where: lower.contains)
            || deleteKeywords.contains(where: lower.contains)
            || priorityKeywords.contains(where: lower.contains)
            || queryKeywords.contains(where: lower.contains)
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
                content: "Couldn't reach AI right now (\(error.localizedDescription)), but here are your top priorities at \(energy.label.lowercased()) energy:\n\n\(topTasks)\n\nFocus on Urgent/High tasks first, then work through the rest.",
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
                content: "AI parsing failed (\(error.localizedDescription)). Tell me about the task — what's it called, when is it due, and how important is it?",
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
                Task { await SupabaseService.shared.syncTask(task) }
                messages.append(AIMessage(
                    content: "Marked \"\(task.title)\" as complete! Nice work 💪",
                    isUser: false,
                    suggestions: [
                        AISuggestion(text: "What's next?", icon: "arrow.right", action: .planDay),
                        AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
                    ]
                ))
            }
        } catch {}
    }

    // MARK: - Natural Language Task Actions

    private func handleNLTaskAction(userMessage: String) async -> AIMessage {
        let tasks = fetchTodayTasks()
        guard !tasks.isEmpty else {
            return AIMessage(
                content: "You don't have any active tasks right now. Want to create one?",
                isUser: false,
                suggestions: [AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))]
            )
        }

        let taskList = tasks.prefix(20).map {
            "- \($0.title) [id:\($0.id.uuidString.prefix(8))]"
        }.joined(separator: "\n")

        let parsePrompt = """
        The user wants to perform a task management action. Parse their request and respond with ONLY valid JSON — no other text, no explanation.

        User request: "\(userMessage)"

        Available tasks:
        \(taskList)

        JSON schema:
        {
          "intent": "reschedule|complete|delete|change_priority|add_to_project|none",
          "taskId": "<first 8 chars of matching task id, or null>",
          "taskTitle": "<matched task title or null>",
          "newDate": "<YYYY-MM-DD or null>",
          "newTime": "<HH:mm or null>",
          "newPriority": <1|2|3|4 or null>,
          "projectName": "<project name or null>",
          "confirmation": "<friendly confirmation message for the user>"
        }

        Today is \(ISO8601DateFormatter().string(from: .now).prefix(10)).
        """

        let llmMessages: [LLMMessage] = [
            LLMMessage(role: .user, content: parsePrompt)
        ]

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: llmMessages,
                temperature: 0.1,
                maxTokens: 300
            )

            // Extract JSON from response (Claude may wrap it in markdown fences)
            let jsonString = extractJSON(from: raw)

            guard let data = jsonString.data(using: .utf8),
                  let intent = try? JSONDecoder().decode(NLTaskIntent.self, from: data) else {
                return await handleGeneralChat(userMessage: userMessage)
            }

            if intent.intent == "none" {
                return await handleGeneralChat(userMessage: userMessage)
            }

            return await executeNLIntent(intent, allTasks: tasks)
        } catch {
            return await handleGeneralChat(userMessage: userMessage)
        }
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }

    private func executeNLIntent(_ intent: NLTaskIntent, allTasks: [FDTask]) async -> AIMessage {
        guard let context = modelContext else {
            return AIMessage(content: "Couldn't access your tasks right now.", isUser: false)
        }

        // Find matching task by partial id or title
        var targetTask: FDTask?
        if let taskId = intent.taskId {
            targetTask = allTasks.first { $0.id.uuidString.prefix(8) == taskId }
        }
        if targetTask == nil, let title = intent.taskTitle {
            targetTask = allTasks.first {
                $0.title.lowercased().contains(title.lowercased()) ||
                title.lowercased().contains($0.title.lowercased())
            }
        }

        guard let task = targetTask else {
            let taskList = allTasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            return AIMessage(
                content: "I couldn't find that task. Which one did you mean?\n\n\(taskList)",
                isUser: false
            )
        }

        switch intent.intent {
        case "complete":
            task.complete()
            try? context.save()
            Task { await SupabaseService.shared.syncTask(task) }

        case "delete":
            task.softDelete()
            try? context.save()
            Task { await SupabaseService.shared.syncTask(task) }

        case "reschedule":
            if let dateStr = intent.newDate {
                var newDate = parseDate(dateStr)
                if let timeStr = intent.newTime, let base = newDate {
                    newDate = applyTime(timeStr, to: base)
                }
                if let date = newDate {
                    task.dueDate = date
                    task.scheduledTime = intent.newTime != nil ? newDate : task.scheduledTime
                    task.modifiedAt = .now
                    try? context.save()
                    Task { await SupabaseService.shared.syncTask(task) }
                }
            }

        case "change_priority":
            if let p = intent.newPriority, let priority = TaskPriority(rawValue: p) {
                task.priority = priority
                task.modifiedAt = .now
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
            }

        case "add_to_project":
            if let projectName = intent.projectName {
                let projects = fetchProjects()
                if let project = projects.first(where: { $0.name.lowercased() == projectName.lowercased() }) {
                    task.project = project
                    task.modifiedAt = .now
                    try? context.save()
                    Task { await SupabaseService.shared.syncTask(task) }
                }
            }

        default:
            break
        }

        return AIMessage(
            content: intent.confirmation,
            isUser: false,
            suggestions: [
                AISuggestion(text: "What's next?", icon: "arrow.right", action: .planDay),
                AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
            ]
        )
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: dateStr) { return date }

        // Try relative day names
        let lower = dateStr.lowercased()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)

        let dayMap = ["monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5,
                      "friday": 6, "saturday": 7, "sunday": 1]
        if let targetWeekday = dayMap.first(where: { lower.contains($0.key) })?.value {
            var daysAhead = targetWeekday - weekday
            if daysAhead <= 0 { daysAhead += 7 }
            return cal.date(byAdding: .day, value: daysAhead, to: today)
        }
        if lower.contains("tomorrow") { return cal.date(byAdding: .day, value: 1, to: today) }
        if lower.contains("today") { return today }
        return nil
    }

    private func applyTime(_ timeStr: String, to date: Date) -> Date? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }

    // MARK: - Reschedule Task (Natural Language)

    private func handleRescheduleTask(userMessage: String) async -> AIMessage {
        let tasks = fetchTodayTasks() + fetchAllPendingTasks()
        let lower = userMessage.lowercased()

        // Try to find the task mentioned
        let match = findBestTaskMatch(in: tasks, for: lower)

        guard let task = match else {
            let taskList = tasks.prefix(8).map { "• \($0.title)" }.joined(separator: "\n")
            return AIMessage(
                content: "Which task do you want to reschedule? Here are your active ones:\n\n\(taskList)",
                isUser: false
            )
        }

        // Try to parse the date from the message
        let newDate = parseNaturalDate(from: userMessage)

        if let newDate {
            task.scheduledTime = newDate
            task.modifiedAt = .now
            try? modelContext?.save()
            Task { await SupabaseService.shared.syncTask(task) }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return AIMessage(
                content: "Done! Moved **\(task.title)** to \(formatter.string(from: newDate)).",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                    AISuggestion(text: "Undo", icon: "arrow.uturn.backward", action: .showProductivity)
                ]
            )
        } else {
            return AIMessage(
                content: "I found **\(task.title)** — when would you like to move it to? You can say things like \"tomorrow at 2pm\", \"next Monday\", or \"Friday morning\".",
                isUser: false
            )
        }
    }

    // MARK: - Delete Task (Natural Language)

    private func handleDeleteTask(userMessage: String) async -> AIMessage {
        let tasks = fetchTodayTasks() + fetchAllPendingTasks()
        let lower = userMessage.lowercased()

        let match = findBestTaskMatch(in: tasks, for: lower)

        guard let task = match else {
            let taskList = tasks.prefix(8).map { "• \($0.title)" }.joined(separator: "\n")
            return AIMessage(
                content: "Which task do you want to delete? Here are your active ones:\n\n\(taskList)",
                isUser: false
            )
        }

        return AIMessage(
            content: "Delete **\(task.title)**? This can be undone.",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Yes, delete it", icon: "trash", action: .deleteTask(id: task.id)),
                AISuggestion(text: "No, keep it", icon: "xmark", action: .showProductivity)
            ]
        )
    }

    func deleteTask(id: UUID) {
        guard let context = modelContext else { return }
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            if let task = all.first(where: { $0.id == id }) {
                task.softDelete()
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
                messages.append(AIMessage(
                    content: "Deleted **\(task.title)**. You can undo this from the task list.",
                    isUser: false,
                    suggestions: [
                        AISuggestion(text: "What's next?", icon: "arrow.right", action: .planDay),
                        AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))
                    ]
                ))
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Change Priority (Natural Language)

    private func handleChangePriority(userMessage: String) async -> AIMessage {
        let tasks = fetchTodayTasks() + fetchAllPendingTasks()
        let lower = userMessage.lowercased()

        let match = findBestTaskMatch(in: tasks, for: lower)

        guard let task = match else {
            let taskList = tasks.prefix(8).map { "• \($0.title) [P\($0.priority.rawValue)]" }.joined(separator: "\n")
            return AIMessage(
                content: "Which task should I change the priority for?\n\n\(taskList)",
                isUser: false
            )
        }

        // Try to parse new priority
        let newPriority: TaskPriority
        if lower.contains("p1") || lower.contains("urgent") || lower.contains("highest") {
            newPriority = .urgent
        } else if lower.contains("p2") || lower.contains("high") || lower.contains("important") {
            newPriority = .high
        } else if lower.contains("p3") || lower.contains("medium") {
            newPriority = .medium
        } else if lower.contains("p4") || lower.contains("low") || lower.contains("no priority") {
            newPriority = .none
        } else {
            return AIMessage(
                content: "What priority should **\(task.title)** be? Choose Urgent, High, Medium, or Low.",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Urgent", icon: "flag.fill", action: .changePriority(id: task.id, priority: 1)),
                    AISuggestion(text: "High",   icon: "flag.fill", action: .changePriority(id: task.id, priority: 2)),
                    AISuggestion(text: "Medium", icon: "flag.fill", action: .changePriority(id: task.id, priority: 3)),
                    AISuggestion(text: "Low",    icon: "flag",       action: .changePriority(id: task.id, priority: 4))
                ]
            )
        }

        task.priority = newPriority
        task.modifiedAt = .now
        try? modelContext?.save()
        Task { await SupabaseService.shared.syncTask(task) }

        return AIMessage(
            content: "Updated **\(task.title)** to priority \(newPriority.label).",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
            ]
        )
    }

    func setPriority(id: UUID, priority: Int) {
        guard let context = modelContext else { return }
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            if let task = all.first(where: { $0.id == id }) {
                task.priority = TaskPriority(rawValue: priority) ?? .medium
                task.modifiedAt = .now
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
                messages.append(AIMessage(
                    content: "Set **\(task.title)** to \(task.priority.label). Anything else?",
                    isUser: false
                ))
            }
        } catch { }
    }

    // MARK: - Natural Language Helpers

    /// Fetch all non-deleted, non-completed tasks (broader than today)
    private func fetchAllPendingTasks() -> [FDTask] {
        guard let context = modelContext else { return [] }
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())
            return all.filter { !$0.isDeleted && !$0.isCompleted }
                .sorted { ($0.priority.rawValue) > ($1.priority.rawValue) }
        } catch {
            return []
        }
    }

    /// Find the best matching task by name from the user's message.
    /// Uses longest-match heuristic: the task whose title has the most
    /// words present in the user message wins.
    private func findBestTaskMatch(in tasks: [FDTask], for loweredMessage: String) -> FDTask? {
        // Remove common command words to avoid false positives
        let noise = Set(["move", "reschedule", "push", "postpone", "delete", "remove", "cancel",
                          "complete", "done", "finish", "mark", "make", "set", "change", "update",
                          "priority", "urgent", "high", "medium", "low", "p1", "p2", "p3", "p4",
                          "to", "the", "my", "a", "an", "it", "task", "for", "on", "at", "in", "is"])

        var bestMatch: FDTask?
        var bestScore = 0

        for task in tasks {
            let titleWords = task.title.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty && !noise.contains($0) }

            let score = titleWords.filter { loweredMessage.contains($0) }.count
            if score > bestScore && score >= max(1, titleWords.count / 2) {
                bestScore = score
                bestMatch = task
            }
        }

        return bestMatch
    }

    /// Parse a natural date expression from the user's message.
    /// Handles common patterns like "tomorrow", "next Monday", "Tuesday at 2pm".
    private func parseNaturalDate(from text: String) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        let now = Date.now

        // "tomorrow"
        if lower.contains("tomorrow") {
            var date = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
            date = applyTimeIfMentioned(lower, to: date) ?? cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
            return date
        }

        // Day of week
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                         "thursday": 5, "friday": 6, "saturday": 7]
        for (name, weekday) in weekdays {
            if lower.contains(name) {
                let today = cal.component(.weekday, from: now)
                var daysAhead = weekday - today
                if daysAhead <= 0 { daysAhead += 7 }
                if lower.contains("next") { daysAhead += 7 }
                var date = cal.date(byAdding: .day, value: daysAhead, to: cal.startOfDay(for: now))!
                date = applyTimeIfMentioned(lower, to: date) ?? cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
                return date
            }
        }

        // "today"
        if lower.contains("today") || lower.contains("this afternoon") || lower.contains("this evening") {
            let date = cal.startOfDay(for: now)
            return applyTimeIfMentioned(lower, to: date) ?? cal.date(bySettingHour: 14, minute: 0, second: 0, of: date)
        }

        // "next week"
        if lower.contains("next week") {
            let date = cal.date(byAdding: .weekOfYear, value: 1, to: cal.startOfDay(for: now))!
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        }

        return nil
    }

    /// Try to find a time in the text and apply it to a date.
    private func applyTimeIfMentioned(_ text: String, to date: Date) -> Date? {
        let cal = Calendar.current

        // "morning"
        if text.contains("morning") {
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        }
        // "afternoon"
        if text.contains("afternoon") {
            return cal.date(bySettingHour: 14, minute: 0, second: 0, of: date)
        }
        // "evening"
        if text.contains("evening") {
            return cal.date(bySettingHour: 18, minute: 0, second: 0, of: date)
        }
        // "Xpm" or "Xam"
        if let range = text.range(of: #"(\d{1,2})\s*(am|pm)"#, options: .regularExpression) {
            let match = String(text[range])
            let digits = match.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if var hour = Int(digits) {
                if match.contains("pm") && hour < 12 { hour += 12 }
                if match.contains("am") && hour == 12 { hour = 0 }
                return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date)
            }
        }
        // "at X:XX"
        if let range = text.range(of: #"at\s+(\d{1,2}):(\d{2})"#, options: .regularExpression) {
            let match = String(text[range])
            let numbers = match.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)
            let parts = numbers.components(separatedBy: ":")
            if parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) {
                return cal.date(bySettingHour: hour, minute: minute, second: 0, of: date)
            }
        }

        return nil
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
                content: "Breakdown failed (\(error.localizedDescription)). Try rephrasing your goal, or create a task directly.",
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
                content: "Connection failed: \(error.localizedDescription)\n\nTry asking me to plan your day or create a task — those work offline too!",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))
                ]
            )
        }
    }

    // MARK: - Natural Language Task Commands (Wave 5c)

    /// Sends the user's NL command to Claude with a task-aware system prompt
    /// that instructs it to embed a JSON action block when modifying tasks.
    private func handleNLTaskCommand(userMessage: String) async -> AIMessage {
        let context = buildUserContext()
        let history = recentConversationHistory()

        let nlSystemContext = """
        \(context)

        TASK MODIFICATION PROTOCOL:
        When the user asks you to modify, reschedule, delete, prioritize, or query tasks, respond conversationally AND include a JSON action block at the very end of your response (after your reply text) in this exact format — no markdown fences, just the raw JSON on its own line:

        {"action":"reschedule","taskQuery":"dentist","newDate":"2026-04-29"}
        {"action":"delete","taskQuery":"grocery list"}
        {"action":"setPriority","taskQuery":"meeting prep","priority":1}
        {"action":"query","filter":"completed","date":"2026-04-23"}
        {"action":"query","filter":"project","projectName":"Johnson"}
        {"action":"query","filter":"count","period":"week"}

        Supported actions: reschedule, delete, setPriority, query
        For dates, use ISO 8601 format (YYYY-MM-DD).
        For priority: 1=urgent, 2=high, 3=medium, 4=none.
        The taskQuery is a short search string to match the task title (case-insensitive).
        ONLY include the JSON if you are performing an action. For pure queries just answer.
        """

        var msgs: [LLMMessage] = [
            LLMMessage(role: .user, content: nlSystemContext),
            LLMMessage(role: .assistant, content: "Got it. I'll help manage your tasks and include action JSON when modifying them.")
        ]
        msgs.append(contentsOf: history)
        msgs.append(LLMMessage(role: .user, content: userMessage))

        do {
            let rawResponse = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: msgs,
                temperature: 0.3,
                maxTokens: 500
            )

            // Parse and execute any embedded action block
            let (displayText, actionResult) = await parseAndExecuteAction(from: rawResponse)
            let finalText = actionResult != nil ? "\(displayText)\n\n✅ \(actionResult!)" : displayText

            return AIMessage(content: finalText, isUser: false)
        } catch {
            return AIMessage(
                content: "I couldn't process that request right now (\(error.localizedDescription)). Try rephrasing.",
                isUser: false
            )
        }
    }

    // MARK: - Action Parsing & Execution

    private struct TaskAction: Decodable {
        let action: String
        let taskQuery: String?
        let newDate: String?
        let priority: Int?
        let filter: String?
        let date: String?
        let projectName: String?
        let period: String?
    }

    /// Splits the AI response into display text and optional action result string.
    private func parseAndExecuteAction(from response: String) async -> (String, String?) {
        // Find a JSON object line at the end of the response
        let lines = response.components(separatedBy: "\n")
        guard let jsonLine = lines.last(where: { $0.hasPrefix("{") && $0.hasSuffix("}") }),
              let data = jsonLine.data(using: .utf8),
              let action = try? JSONDecoder().decode(TaskAction.self, from: data) else {
            return (response, nil)
        }

        // Strip the JSON line from the display text
        let displayText = lines
            .filter { !($0.hasPrefix("{") && $0.hasSuffix("}")) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await executeAction(action)
        return (displayText, result)
    }

    private func executeAction(_ action: TaskAction) async -> String? {
        guard let context = modelContext else { return nil }

        switch action.action {
        case "reschedule":
            guard let query = action.taskQuery, let dateStr = action.newDate else { return nil }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            guard let newDate = fmt.date(from: dateStr) else { return "Couldn't parse date \(dateStr)" }

            do {
                let all = try context.fetch(FetchDescriptor<FDTask>())
                guard let task = all.first(where: {
                    !$0.isDeleted && $0.title.lowercased().contains(query.lowercased())
                }) else { return "Couldn't find a task matching \"\(query)\"" }
                task.dueDate = newDate
                task.modifiedAt = .now
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
                let formatted = DateFormatter.localizedString(from: newDate, dateStyle: .medium, timeStyle: .none)
                return "Rescheduled \"\(task.title)\" to \(formatted)"
            } catch { return nil }

        case "delete":
            guard let query = action.taskQuery else { return nil }
            do {
                let all = try context.fetch(FetchDescriptor<FDTask>())
                guard let task = all.first(where: {
                    !$0.isDeleted && $0.title.lowercased().contains(query.lowercased())
                }) else { return "Couldn't find a task matching \"\(query)\"" }
                task.softDelete()
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
                return "Deleted \"\(task.title)\""
            } catch { return nil }

        case "setPriority":
            guard let query = action.taskQuery, let priorityRaw = action.priority,
                  let priority = TaskPriority(rawValue: priorityRaw) else { return nil }
            do {
                let all = try context.fetch(FetchDescriptor<FDTask>())
                guard let task = all.first(where: {
                    !$0.isDeleted && $0.title.lowercased().contains(query.lowercased())
                }) else { return "Couldn't find a task matching \"\(query)\"" }
                task.priority = priority
                task.modifiedAt = .now
                try? context.save()
                Task { await SupabaseService.shared.syncTask(task) }
                return "Set \"\(task.title)\" to \(priority.label)"
            } catch { return nil }

        case "query":
            return await executeQueryAction(action)

        default:
            return nil
        }
    }

    private func executeQueryAction(_ action: TaskAction) async -> String? {
        guard let context = modelContext else { return nil }

        let filter = action.filter ?? ""
        do {
            let all = try context.fetch(FetchDescriptor<FDTask>())

            switch filter {
            case "completed":
                let targetDate: Date
                if let dateStr = action.date {
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withFullDate]
                    targetDate = fmt.date(from: dateStr) ?? Calendar.current.startOfDay(for: .now)
                } else {
                    targetDate = Calendar.current.startOfDay(for: .now)
                }
                let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
                let completed = all.filter {
                    $0.isCompleted && !$0.isDeleted &&
                    ($0.completedAt ?? .distantPast) >= targetDate &&
                    ($0.completedAt ?? .distantPast) < dayEnd
                }
                if completed.isEmpty { return "No completed tasks found for that date" }
                let list = completed.prefix(10).map { "• \($0.title)" }.joined(separator: "\n")
                return "Found \(completed.count) completed task(s):\n\(list)"

            case "project":
                guard let proj = action.projectName else { return nil }
                let matches = all.filter {
                    !$0.isDeleted && ($0.project?.name.lowercased().contains(proj.lowercased()) == true)
                }
                if matches.isEmpty { return "No tasks found for project \"\(proj)\"" }
                let list = matches.prefix(10).map { "• \($0.title) [\($0.priority.label)]" }.joined(separator: "\n")
                return "Found \(matches.count) task(s) in \"\(proj)\":\n\(list)"

            case "count":
                let period = action.period ?? "week"
                let startDate: Date
                if period == "week" {
                    startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
                } else {
                    startDate = Calendar.current.startOfDay(for: .now)
                }
                let count = all.filter {
                    $0.isCompleted && !$0.isDeleted &&
                    ($0.completedAt ?? .distantPast) >= startDate
                }.count
                return "You completed \(count) task(s) this \(period)"

            default:
                return nil
            }
        } catch { return nil }
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
        case .rescheduleTask(let id, let date):
            let intent = NLTaskIntent(intent: "reschedule", taskId: id.uuidString.prefix(8).description,
                                      taskTitle: nil, newDate: ISO8601DateFormatter().string(from: date).prefix(10).description,
                                      newTime: nil, newPriority: nil, projectName: nil,
                                      confirmation: "Rescheduled!")
            Task {
                let tasks = fetchTodayTasks()
                let msg = await executeNLIntent(intent, allTasks: tasks)
                await appendMessage(msg)
            }
        case .deleteTask(let id):
            let intent = NLTaskIntent(intent: "delete", taskId: id.uuidString.prefix(8).description,
                                      taskTitle: nil, newDate: nil, newTime: nil, newPriority: nil,
                                      projectName: nil, confirmation: "Task deleted.")
            Task {
                let tasks = fetchTodayTasks()
                let msg = await executeNLIntent(intent, allTasks: tasks)
                await appendMessage(msg)
            }
        case .changePriority(let id, let priority):
            let intent = NLTaskIntent(intent: "change_priority", taskId: id.uuidString.prefix(8).description,
                                      taskTitle: nil, newDate: nil, newTime: nil, newPriority: priority,
                                      projectName: nil, confirmation: "Priority updated!")
            Task {
                let tasks = fetchTodayTasks()
                let msg = await executeNLIntent(intent, allTasks: tasks)
                await appendMessage(msg)
            }
        case .addToProject(let id, let projectName):
            let intent = NLTaskIntent(intent: "add_to_project", taskId: id.uuidString.prefix(8).description,
                                      taskTitle: nil, newDate: nil, newTime: nil, newPriority: nil,
                                      projectName: projectName, confirmation: "Added to \(projectName)!")
            Task {
                let tasks = fetchTodayTasks()
                let msg = await executeNLIntent(intent, allTasks: tasks)
                await appendMessage(msg)
            }
        case .executeNLAction(let intent):
            Task {
                let tasks = fetchTodayTasks()
                let msg = await executeNLIntent(intent, allTasks: tasks)
                await appendMessage(msg)
            }
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
