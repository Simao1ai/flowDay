// AIAssistantView.swift
// FlowDay
//
// Flow AI — modern ChatGPT-style productivity assistant with frosted input
// bar, animated typing indicator, and markdown rendering.

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
    @State private var showProUpgrade = false
    @FocusState private var isFocused: Bool

    private var proAccess: ProAccessManager { .shared }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                messagesList
                    .safeAreaInset(edge: .bottom) {
                        inputAreaSpacer
                    }
            }

            VStack(spacing: 0) {
                if !proAccess.isPro && !aiService.showUpgradePrompt {
                    callsRemainingBanner
                }
                if aiService.showUpgradePrompt {
                    upgradePrompt
                }
                if aiService.messages.count == 1 {
                    quickSuggestions
                }
                inputBar
            }
        }
        .sheet(isPresented: $showProUpgrade) { ProUpgradeView(highlightedFeature: .unlimitedAI) }
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
        .paywall(isPresented: .constant(false), feature: .aiChat)
        .onAppear {
            aiService.modelContext = modelContext
        }
    }

    // MARK: - Spacer to keep messages above the input bar

    private var inputAreaSpacer: some View {
        Color.clear.frame(height: inputBarHeight)
    }

    private var inputBarHeight: CGFloat {
        var h: CGFloat = 72
        if !proAccess.isPro && !aiService.showUpgradePrompt { h += 36 }
        if aiService.showUpgradePrompt { h += 68 }
        if aiService.messages.count == 1 { h += 56 }
        return h
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fdText)
                    .frame(width: 32, height: 32)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Circle())
            }

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Flow AI")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Your productivity assistant")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
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
                Button(action: { aiService.clearChat() }) {
                    Label("New Chat", systemImage: "plus.message")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fdText)
                    .frame(width: 32, height: 32)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Calls Remaining Banner

    private var callsRemainingBanner: some View {
        let remaining = proAccess.aiCallsRemaining
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<proAccess.freeAILimit, id: \.self) { i in
                    Capsule()
                        .fill(i < remaining ? Color.fdAccent : Color.fdBorder)
                        .frame(width: 16, height: 4)
                }
            }
            Text(remaining == 0
                 ? "No free calls left today"
                 : "\(remaining) of \(proAccess.freeAILimit) free calls left")
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextSecondary)
            Spacer()
            Button("Go Pro") { showProUpgrade = true }
                .font(.fdMicro)
                .fontWeight(.semibold)
                .foregroundStyle(Color.fdAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Upgrade Prompt

    private var upgradePrompt: some View {
        Button(action: { showProUpgrade = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily limit reached")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Unlock unlimited AI chat with Pro")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(aiService.messages) { message in
                        MessageBubble(message: message, onSuggestTap: { suggestion in
                            aiService.handleSuggestion(suggestion)
                        })
                        .id(message.id)
                    }

                    if aiService.isTyping {
                        TypingIndicator()
                            .id("typing")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: aiService.messages.count) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    proxy.scrollTo(aiService.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: aiService.isTyping) {
                if aiService.isTyping {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Quick Suggestions

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickSuggestionChip(text: "🗓 Plan my day") {
                        aiService.sendMessage("Help me plan my day")
                    }
                    QuickSuggestionChip(text: "✨ Generate tasks") {
                        aiService.sendMessage("Generate some tasks for me")
                    }
                    QuickSuggestionChip(text: "📊 My progress") {
                        aiService.sendMessage("How am I doing today?")
                    }
                    QuickSuggestionChip(text: "💡 Suggest template") {
                        aiService.sendMessage("Suggest a template for me")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Input Bar (Frosted Glass)

    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Message Flow AI...", text: $inputText, axis: .vertical)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1...5)
                    .focused($isFocused)

                if !inputText.isEmpty {
                    Button { inputText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.fdTextMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.fdBorder, lineWidth: 0.5))

            if inputText.isEmpty {
                Button(action: {
                    Haptics.tap()
                    showVoiceInput = true
                }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                }
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .animation(.spring(response: 0.3), value: inputText.isEmpty)
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Haptics.tock()
        aiService.sendMessage(trimmed)
        inputText = ""
        isFocused = false
    }
}

#Preview {
    AIAssistantView()
}
