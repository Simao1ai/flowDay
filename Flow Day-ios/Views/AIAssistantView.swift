import SwiftUI
import Speech
import AVFoundation

// MARK: - AI Message Models

struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = .now
    var suggestions: [AISuggestion]? = nil
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let action: AIAction
}

enum AIAction {
    case createTask(title: String)
    case planDay
    case generateTemplate(category: String)
    case suggestBreak
    case showProductivity
}

// MARK: - AI Assistant Service

@Observable
class AIAssistantService {
    var messages: [AIMessage] = []
    var isTyping: Bool = false
    var showUpgradePrompt: Bool = false

    init() {
        let welcomeMessage = AIMessage(
            content: "Hi! I'm Flow, your AI productivity assistant. I can help you plan your day, create tasks, generate templates, and more. What would you like to do?",
            isUser: false,
            suggestions: [
                AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: "")),
                AISuggestion(text: "Browse templates", icon: "doc.text", action: .generateTemplate(category: "General")),
                AISuggestion(text: "How am I doing?", icon: "chart.bar", action: .showProductivity)
            ]
        )
        self.messages = [welcomeMessage]
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = AIMessage(content: text, isUser: true)
        messages.append(userMessage)

        isTyping = true

        Task {
            await generateAIResponse(for: text)
        }
    }

    private func generateAIResponse(for userMessage: String) async {
        defer { isTyping = false }

        // Check subscription usage
        guard SubscriptionManager.shared.hasRemainingUsage(.aiChat) else {
            showUpgradePrompt = true
            let upgradeMessage = AIMessage(
                content: "You've reached your daily AI chat limit. Upgrade to Pro for unlimited access!",
                isUser: false
            )
            await MainActor.run {
                messages.append(upgradeMessage)
            }
            return
        }

        let lowerMessage = userMessage.lowercased()

        // Build conversation history for context
        let conversationHistory: [LLMMessage] = messages.map { message in
            LLMMessage(
                role: message.isUser ? .user : .assistant,
                content: message.content
            )
        }

        var aiResponse: AIMessage?

        // Handle specific action patterns
        if lowerMessage.contains("plan") || lowerMessage.contains("schedule") {
            aiResponse = await handlePlanDay()
        } else if lowerMessage.contains("create") || lowerMessage.contains("task") {
            aiResponse = await handleCreateTask(userMessage: userMessage)
        } else {
            // General chat with LLM
            aiResponse = await handleGeneralChat(userMessage: userMessage, conversationHistory: conversationHistory)
        }

        // Add response to messages
        if let response = aiResponse {
            await MainActor.run {
                messages.append(response)
                SubscriptionManager.shared.incrementUsage(.aiChat)
            }
        }
    }

    private func handlePlanDay() async -> AIMessage {
        // TODO: Integrate with model context to get actual tasks, energy level, calendar events, and free slots
        // For now, call with empty arrays and default energy
        do {
            let plan = try await AIFeatureService.shared.generateSmartPlan(
                tasks: [],
                energyLevel: .normal,
                calendarEvents: [],
                freeSlots: []
            )

            let taskList = plan.scheduledTasks.map { "\($0.taskTitle) at \($0.suggestedTime)" }.joined(separator: "\n")
            let planText = """
            Here's your smart plan for today:

            \(plan.summary)

            \(taskList.isEmpty ? "No tasks scheduled yet — add some tasks first!" : taskList)

            Tips: \(plan.tips.joined(separator: " • "))
            """

            return AIMessage(
                content: planText,
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Save plan", icon: "checkmark.circle", action: .planDay),
                    AISuggestion(text: "Adjust", icon: "slider.horizontal.3", action: .createTask(title: ""))
                ]
            )
        } catch {
            return AIMessage(
                content: "I'd love to help you plan your day! Let me create an optimized schedule for you. What are your top priorities today?",
                isUser: false
            )
        }
    }

    private func handleCreateTask(userMessage: String) async -> AIMessage {
        do {
            let suggestion = try await AIFeatureService.shared.parseTaskWithAI(input: userMessage)

            return AIMessage(
                content: "I can create a task: '\(suggestion.title)' with priority \(suggestion.priority) and duration \(suggestion.estimatedMinutes ?? 30) minutes. Should I add it?",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Create it", icon: "checkmark.circle", action: .createTask(title: suggestion.title)),
                    AISuggestion(text: "Modify", icon: "pencil", action: .createTask(title: suggestion.title))
                ]
            )
        } catch {
            return AIMessage(
                content: "I can help you create a task. What's the task name, priority, and how long do you think it will take?",
                isUser: false
            )
        }
    }

    private func handleGeneralChat(userMessage: String, conversationHistory: [LLMMessage]) async -> AIMessage {
        let systemPrompt = """
        You are Flow, FlowDay's AI productivity assistant. You help users manage tasks, plan their day, and stay productive. You're warm, encouraging, and concise. You know about the user's tasks, projects, and energy levels. Keep responses short (2-3 sentences) unless the user asks for detail. Use bullet points sparingly. Never use markdown headers.
        """

        do {
            let response = try await LLMService.shared.chat(
                messages: conversationHistory,
                systemPrompt: systemPrompt,
                temperature: 0.7,
                maxTokens: 300
            )

            return AIMessage(content: response, isUser: false)
        } catch {
            return AIMessage(
                content: "That's interesting! I can help with task management, day planning, productivity insights, and more. Try asking me to plan your day or create a task.",
                isUser: false,
                suggestions: [
                    AISuggestion(text: "Plan my day", icon: "calendar", action: .planDay),
                    AISuggestion(text: "Create a task", icon: "plus.circle", action: .createTask(title: ""))
                ]
            )
        }
    }

    func handleSuggestion(_ suggestion: AISuggestion) {
        switch suggestion.action {
        case .createTask(let title):
            sendMessage("Create a task for me" + (title.isEmpty ? "" : ": \(title)"))
        case .planDay:
            sendMessage("Help me plan my day")
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
    @State private var aiService = AIAssistantService()
    @State private var inputText: String = ""
    @State private var showVoiceInput = false
    @State private var showShareOptions = false
    @State private var showCollaborate = false
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
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.fdAccent)
                            Text("Upgrade to Pro")
                                .font(.fdBodySemibold)
                                .foregroundColor(.fdText)
                            Spacer()
                            Button(action: { aiService.showUpgradePrompt = false }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.fdTextMuted)
                            }
                        }
                        Text("You've used your daily AI chat limit. Upgrade to Pro for unlimited access.")
                            .font(.fdCaption)
                            .foregroundColor(.fdTextSecondary)
                    }
                    .padding()
                    .background(Color.fdAccentLight)
                    .cornerRadius(8)
                    .padding()
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
