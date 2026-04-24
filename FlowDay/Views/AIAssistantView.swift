// AIAssistantView.swift
// FlowDay
//
// Flow AI — chat-style productivity assistant. This file holds just the
// main screen. Supporting pieces moved to:
//   • Views/AI/AIMessageModels.swift — AIMessage / AISuggestion / AIAction
//   • Services/AIAssistantService.swift — chat controller + intent routing
//   • Views/AI/MessageBubble.swift — bubble, typing indicator, chip
//   • Views/AI/VoiceInputView.swift — mic capture sheet
//   • Views/AI/ShareOptionsView.swift — share destination picker
//   • Views/AI/CollaborateView.swift — (placeholder) collaboration invite

import SwiftUI
import SwiftData

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
                navBar
                if aiService.showUpgradePrompt { upgradePrompt }
                messagesList
                if aiService.messages.count == 1 { quickSuggestions }
                inputBar
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
        .paywall(isPresented: $showPaywall, feature: .unlimitedAI)
        .onAppear {
            aiService.modelContext = modelContext
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.fdTitle3)
                    .foregroundColor(.fdText)
            }

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.fdAccent)
                    Text("Flow AI")
                        .font(.fdTitle3)
                        .foregroundColor(.fdText)
                }
                if !ProAccessManager.shared.isPro {
                    let remaining = ProAccessManager.shared.remainingAICalls
                    let limit = ProAccessManager.shared.dailyAICallLimit
                    Text("\(remaining)/\(limit) free calls today")
                        .font(.fdMicro)
                        .foregroundStyle(remaining == 0 ? Color.fdRed : Color.fdTextMuted)
                }
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
    }

    // MARK: - Upgrade Prompt

    private var upgradePrompt: some View {
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

    // MARK: - Messages

    private var messagesList: some View {
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
    }

    // MARK: - Quick Suggestions

    private var quickSuggestions: some View {
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

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask Flow anything...", text: $inputText)
                .font(.fdBody)
                .foregroundColor(.fdText)
                .padding(12)
                .background(Color.fdSurface)
                .cornerRadius(8)
                .border(Color.fdBorder, width: 1)
                .focused($isFocused)

            Button(action: {
                Haptics.tap()
                showVoiceInput = true
            }) {
                Image(systemName: "mic.fill")
                    .font(.fdTitle3)
                    .foregroundColor(.fdAccent)
                    .frame(width: 44, height: 44)
            }

            Button(action: {
                let trimmed = inputText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                Haptics.tock()
                aiService.sendMessage(trimmed)
                inputText = ""
                isFocused = false
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(inputText.isEmpty ? .fdTextMuted : .fdAccent)
            }
            .disabled(inputText.isEmpty)
        }
        .padding()
        .background(Color.fdBackground)
    }
}

#Preview {
    AIAssistantView()
}
