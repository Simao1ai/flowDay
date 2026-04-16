import SwiftUI
import SwiftData
import Speech
import AVFoundation

// MARK: - AI Message Models

struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = .now
    var suggestions: [AISuggestion]? = nil
    /// Holds a pending task the user can confirm
    var pendingTask: AITaskSuggestion? = nil
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let action: AIAction
}

enum AIAction {
    case createTask(title: String)
    case confirmTask          // Confirm and save the pending task
    case planDay
    case breakdownGoal(goal: String)
    case generateTemplate(category: String)
    case suggestBreak
    case showProductivity
    case completeTask(id: UUID)
}

// MARK: - AI Assistant Service (Data-Connected)

@Observable @MainActor
class AIAssistantService {
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

    private func fetchTodayTasks() -> [FDTask] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FDTask>(
            predicate: #Predicate { !$0.isDeleted && !$0.isCompleted },
            sortBy: [SortDescriptor(\.priority), SortDescriptor(\.dueDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchProjects() -> [FDProject] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FDProject>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchTodayEnergy() -> EnergyLevel {
        guard let context = modelContext else { return .normal }
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<FDEnergyLog>(
            predicate: #Predicate { $0.date >= today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first?.level ?? .normal
    }

    private func fetchCompletedTodayCount() -> Int {
        guard let context = modelContext else { return 0 }
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<FDTask>(
            predicate: #Predicate { $0.isCompleted && !$0.isDeleted && $0.completedAt != nil && $0.completedAt! >= today }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
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

        // Get calendar free slots
        let calendarService = CalendarService()
        calendarService.fetchTodayEvents()
        let events = calendarService.todayEvents.map { "\($0.title ?? "Event") at \(DateFormatter.localizedString(from: $0.startDate, dateStyle: .none, timeStyle: .short))" }
        let freeSlots = calendarService.freeSlots(for: .now)

        do {
            let plan = try await AIFeatureService.shared.generateSmartPlan(
                tasks: Array(tasks.prefix(20)),
                energyLevel: energy,
                calendarEvents: events,
                freeSlots: freeSlots.map { (start: $0.start, end: Calendar.current.date(byAdding: .minute, value: $0.durationMinutes, to: $0.start) ?? $0.start) }
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
            // Fallback: simple summary from real data
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
            let suggestion = try await AIFeatureService.shared.parseTaskWithAI(input: userMessage)
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

        // Parse due date if present
        var dueDate: Date? = nil
        if let dueDateString = suggestion.dueDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            dueDate = formatter.date(from: dueDateString)
        }

        // Find matching project
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

        let projectNote = project != nil ? " in \(project!.name)" : ""
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

        // Find best matching task
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

        // If no match, list tasks
        let taskList = tasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        return AIMessage(
            content: "Which task did you complete? Here are your active ones:\n\n\(taskList)",
            isUser: false
        )
    }

    func completeTask(id: UUID) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FDTask>(predicate: #Predicate { $0.id == id })
        if let task = try? context.fetch(descriptor).first {
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
            let breakdown = try await AIFeatureService.shared.breakdownTask(goal: goal)

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

    // MARK: - General Chat (context-rich)

    private func handleGeneralChat(userMessage: String) async -> AIMessage {
        let context = buildUserContext()
        let conversationHistory: [LLMMessage] = messages.suffix(10).map { msg in
            LLMMessage(role: msg.isUser ? .user : .assistant, content: msg.content)
        }

        let systemPrompt = """
        You are Flow, FlowDay's AI productivity assistant. You're warm, encouraging, and concise (2-3 sentences max unless asked for detail). Never use markdown headers.

        You have REAL access to the user's data. Use it to give personalized advice.

        \(context)

        CAPABILITIES you can suggest:
        - "Plan my day" — generates an energy-aware schedule
        - "Create a task: [description]" — parses natural language into a task
        - "Break down [goal]" — splits a goal into subtasks
        - "Complete [task name]" — marks a task done
        - "How am I doing?" — shows productivity stats
        """

        do {
            let response = try await LLMService.shared.chat(
                messages: conversationHistory,
                systemPrompt: systemPrompt,
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

    // MARK: - Handle Suggestion Taps

    func handleSuggestion(_ suggestion: AISuggestion) {
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

// MARK: - Speech Recognizer
// Real SpeechRecognizer class is now in Services/SpeechRecognizer.swift

// MARK: - Voice Input View

struct VoiceInputView: View {
    @Environment(\.dismiss) var dismiss
    @State private var speechRecognizer = SpeechRecognizer()
    var onSend: (String) -> Void

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)
                    }
                    Spacer()
                    Text("Voice Input")
                        .font(.fdTitle3)
                        .foregroundColor(.fdText)
                    Spacer()
                    Color.clear
                        .frame(width: 44)
                }
                .padding()

                Spacer()

                VStack(spacing: 24) {
                    // Pulsing microphone circle
                    ZStack {
                        Circle()
                            .fill(Color.fdAccent)
                            .frame(width: 120, height: 120)
                            .scaleEffect(speechRecognizer.isListening ? 1.2 : 1.0)
                            .opacity(speechRecognizer.isListening ? 0.3 : 1.0)
                            .animation(
                                speechRecognizer.isListening ?
                                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                                .default,
                                value: speechRecognizer.isListening
                            )

                        Image(systemName: "mic.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }

                    // Status text
                    VStack(spacing: 12) {
                        Text(speechRecognizer.isListening ? "Listening..." : "Ready to listen")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)

                        // Waveform animation
                        if speechRecognizer.isListening {
                            HStack(alignment: .center, spacing: 6) {
                                ForEach(0..<5, id: \.self) { index in
                                    WaveformBar(index: index)
                                }
                            }
                            .frame(height: 40)
                        }
                    }

                    // Transcribed text
                    if !speechRecognizer.transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recognized Text")
                                .font(.fdCaptionBold)
                                .foregroundColor(.fdTextSecondary)

                            Text(speechRecognizer.transcribedText)
                                .font(.fdBody)
                                .foregroundColor(.fdText)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.fdSurface)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        speechRecognizer.stopListening()
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.fdBodySemibold)
                            .foregroundColor(.fdText)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.fdSurfaceHover)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        speechRecognizer.stopListening()
                        onSend(speechRecognizer.transcribedText)
                        dismiss()
                    }) {
                        Text("Send")
                            .font(.fdBodySemibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.fdAccent)
                            .cornerRadius(8)
                    }
                    .disabled(speechRecognizer.transcribedText.isEmpty)
                }
                .padding()
            }
        }
        .onAppear {
            speechRecognizer.startListening()
        }
    }
}

struct WaveformBar: View {
    let index: Int
    @State private var height: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.fdAccent)
            .frame(width: 4, height: height)
            .animation(
                Animation.easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1),
                value: height
            )
            .onAppear {
                height = CGFloat.random(in: 10...40)
            }
    }
}

// MARK: - Share Models and Views

struct TaskShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showActivitySheet = false
    let taskTitle: String

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Share Task")
                    .font(.fdTitle3)
                    .foregroundColor(.fdText)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.fdTextMuted)
                }
            }
            .padding()

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ShareOptionButton(
                        icon: "airplane.circle.fill",
                        label: "AirDrop",
                        color: .fdBlue
                    )

                    ShareOptionButton(
                        icon: "message.circle.fill",
                        label: "Messages",
                        color: .fdGreen
                    )

                    ShareOptionButton(
                        icon: "envelope.circle.fill",
                        label: "Email",
                        color: .fdRed
                    )

                    ShareOptionButton(
                        icon: "link.circle.fill",
                        label: "Copy Link",
                        color: .fdAccent
                    )
                }

                HStack {
                    Button(action: { showActivitySheet = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.fdPurple)

                            Text("More")
                                .font(.fdCaption)
                                .foregroundColor(.fdText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.fdSurface)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    Spacer()
                }
            }
            .padding()

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.fdBodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.fdAccent)
                    .cornerRadius(8)
            }
            .padding()
        }
        .background(Color.fdBackground)
        .sheet(isPresented: $showActivitySheet) {
            TaskShareSheet(items: [taskTitle])
        }
    }
}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(label)
                .font(.fdCaption)
                .foregroundColor(.fdText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.fdSurface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CollaborateView: View {
    @Environment(\.dismiss) var dismiss
    @State private var emailInput: String = ""
    @State private var selectedPermission: String = "Can View"
    let projectName: String

    let collaborators = [
        ("Sarah Chen", "sarah@flowday.app"),
        ("Marcus Johnson", "marcus@company.com")
    ]

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("Invite to Project")
                        .font(.fdTitle3)
                        .foregroundColor(.fdText)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.fdTextMuted)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 20) {
                        // Invite section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Invite Collaborators")
                                .font(.fdTitle3)
                                .foregroundColor(.fdText)

                            TextField("Email address", text: $emailInput)
                                .font(.fdBody)
                                .padding(12)
                                .background(Color.fdSurface)
                                .cornerRadius(8)
                                .border(Color.fdBorder, width: 1)

                            Picker("Permission", selection: $selectedPermission) {
                                Text("Can View").tag("Can View")
                                Text("Can Edit").tag("Can Edit")
                            }
                            .font(.fdBody)
                            .padding(12)
                            .background(Color.fdSurface)
                            .cornerRadius(8)

                            Button(action: {}) {
                                Text("Send Invite")
                                    .font(.fdBodySemibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.fdAccent)
                                    .cornerRadius(8)
                            }
                            .disabled(emailInput.isEmpty)
                        }
                        .padding()
                        .background(Color.fdSurface)
                        .cornerRadius(8)

                        // Current collaborators
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project Members")
                                .font(.fdTitle3)
                                .foregroundColor(.fdText)

                            ForEach(collaborators, id: \.1) { name, email in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.fdAccent.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(name.prefix(1)))
                                                .font(.fdBodySemibold)
                                                .foregroundColor(.fdAccent)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.fdBodySemibold)
                                            .foregroundColor(.fdText)
                                        Text(email)
                                            .font(.fdCaption)
                                            .foregroundColor(.fdTextSecondary)
                                    }

                                    Spacer()

                                    Text("Can Edit")
                                        .font(.fdCaption)
                                        .foregroundColor(.fdTextMuted)
                                }
                                .padding(12)
                                .background(Color.fdSurfaceHover)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.fdSurface)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Main AI Assistant View

struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var aiService = AIAssistantService()
    @State private var inputText: String = ""
    @State private var showVoiceInput = false
    @State private var showShareOptions = false
    @State private var showCollaborate = false
    @State private var showPaywall = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Navigation Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.fdAccent)
                        Text("Flow AI")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)
                    }

                    Spacer()

                    Menu {
                        Button(action: { showShareOptions = true }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { showCollaborate = true }) {
                            Label("Collaborate", systemImage: "person.2")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.fdText)
                    }
                }
                .padding()
                .background(Color.fdSurface)
                .border(Color.fdBorder, width: 1)

                // MARK: Upgrade Prompt (if shown)
                if aiService.showUpgradePrompt {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Color.fdAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily limit reached")
                                    .font(.fdBodySemibold)
                                    .foregroundStyle(Color.fdText)
                                Text("Tap to unlock unlimited AI chat")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding()
                        .background(Color.fdAccentLight)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                // MARK: Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(aiService.messages) { message in
                                MessageBubble(message: message, onSuggestTap: { suggestion in
                                    aiService.handleSuggestion(suggestion)
                                })
                                .id(message.id)
                            }

                            if aiService.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding()
                        .onChange(of: aiService.messages.count) {
                            withAnimation {
                                proxy.scrollTo(aiService.messages.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: aiService.isTyping) {
                            if aiService.isTyping {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // MARK: Quick Suggestions (when no messages beyond welcome)
                if aiService.messages.count == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.fdCaption)
                            .foregroundColor(.fdTextSecondary)
                            .padding(.horizontal)

                        HStack(spacing: 8) {
                            QuickSuggestionChip(text: "🗓 Plan my day") {
                                aiService.sendMessage("Help me plan my day")
                            }

                            QuickSuggestionChip(text: "✨ Generate tasks") {
                                aiService.sendMessage("Generate some tasks for me")
                            }

                            QuickSuggestionChip(text: "📊 My productivity") {
                                aiService.sendMessage("How am I doing today?")
                            }

                            QuickSuggestionChip(text: "💡 Suggest a template") {
                                aiService.sendMessage("Suggest a template for me")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color.fdSurface)
                    .border(Color.fdBorder, width: 1)
                }

                // MARK: Input Bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Ask Flow anything...", text: $inputText)
                            .font(.fdBody)
                            .foregroundColor(.fdText)
                            .padding(12)
                            .background(Color.fdSurface)
                            .cornerRadius(8)
                            .border(Color.fdBorder, width: 1)
                            .focused($isFocused)

                        Button(action: { showVoiceInput = true }) {
                            Image(systemName: "mic.fill")
                                .font(.fdTitle3)
                                .foregroundColor(.fdAccent)
                                .frame(width: 44, height: 44)
                        }

                        Button(action: {
                            aiService.sendMessage(inputText)
                            inputText = ""
                            isFocused = false
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(inputText.isEmpty ? .fdTextMuted : .fdAccent)
                        }
                        .disabled(inputText.isEmpty)
                    }
                }
                .padding()
                .background(Color.fdBackground)
            }
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputView { text in
                aiService.sendMessage(text)
                inputText = ""
            }
        }
        .sheet(isPresented: $showShareOptions) {
            ShareOptionsView(taskTitle: "My Task")
        }
        .sheet(isPresented: $showCollaborate) {
            CollaborateView(projectName: "My Project")
        }
        .paywall(isPresented: $showPaywall, feature: .aiChat)
        .onAppear {
            aiService.modelContext = modelContext
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    let onSuggestTap: (AISuggestion) -> Void

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.isUser { Spacer() }

                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    Text(message.content)
                        .font(.fdBody)
                        .foregroundColor(message.isUser ? .white : .fdText)

                    if let suggestions = message.suggestions, !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions) { suggestion in
                                Button(action: { onSuggestTap(suggestion) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: suggestion.icon)
                                            .font(.caption)
                                        Text(suggestion.text)
                                            .font(.fdCaption)
                                    }
                                    .foregroundColor(message.isUser ? .white : .fdAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        message.isUser ?
                                        Color.white.opacity(0.2) :
                                        Color.fdAccentLight
                                    )
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(message.isUser ? Color.fdAccent : Color.fdSurface)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: message.isUser ? 16 : 4,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: message.isUser ? 4 : 16
                    )
                )

                if !message.isUser { Spacer() }
            }

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.fdMicro)
                .foregroundColor(.fdTextMuted)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.fdTextMuted)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .padding(12)
        .background(Color.fdSurface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        )
        .padding(.horizontal)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Quick Suggestion Chip

struct QuickSuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.fdCaption)
                .foregroundColor(.fdText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.fdSurfaceHover)
                .cornerRadius(16)
                .lineLimit(1)
        }
    }
}

// UnevenRoundedRectangle is used for chat bubble shapes (iOS 17+)

// MARK: - Preview

#Preview {
    AIAssistantView()
}
