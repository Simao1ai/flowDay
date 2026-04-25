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
    @State private var showPaywall = false
    @State private var showProUpgrade = false
    @FocusState private var isFocused: Bool

    private var proAccess: ProAccessManager { .shared }

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                if !proAccess.isPro && !aiService.showUpgradePrompt {
                    callsRemainingBanner
                }
                if aiService.showUpgradePrompt { upgradePrompt }
                messagesList
                if aiService.messages.count == 1 { quickSuggestions }
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
        .paywall(isPresented: $showPaywall, feature: .aiChat)
        .onAppear {
            aiService.modelContext = modelContext
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fdText)
                    .frame(width: 36, height: 36)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Circle())
            }

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.fdAccent, Color.fdPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fdText)
                    .frame(width: 36, height: 36)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.fdSurface.opacity(0.85))
        .background(.ultraThinMaterial)
    }

    // MARK: - Calls Remaining Banner

    private var callsRemainingBanner: some View {
        let remaining = proAccess.aiCallsRemaining
        return HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fdAccent)
            Text(remaining == 0
                 ? "No free AI calls left today"
                 : "\(remaining)/\(proAccess.freeAILimit) free AI calls remaining today")
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
        .background(Color.fdAccentLight)
    }

    // MARK: - Upgrade Prompt

    private var upgradePrompt: some View {
        Button(action: { showProUpgrade = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.fdAccent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.fdAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily limit reached")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Upgrade for unlimited AI chat")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(14)
            .background(Color.fdAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.fdAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(aiService.messages) { message in
                        ModernMessageBubble(message: message, onSuggestTap: { suggestion in
                            aiService.handleSuggestion(suggestion)
                        })
                        .id(message.id)
                    }

                    if aiService.isTyping {
                        ModernTypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.vertical, 12)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ModernSuggestionPill(icon: "calendar", text: "Plan my day", color: .fdAccent) {
                        aiService.sendMessage("Help me plan my day")
                    }
                    ModernSuggestionPill(icon: "plus.circle", text: "Create a task", color: .fdGreen) {
                        aiService.sendMessage("Create a task")
                    }
                    ModernSuggestionPill(icon: "chart.bar", text: "My progress", color: .fdBlue) {
                        aiService.sendMessage("How am I doing today?")
                    }
                    ModernSuggestionPill(icon: "sparkles", text: "Suggest template", color: .fdPurple) {
                        aiService.sendMessage("Suggest a template for me")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(Color.fdSurface.opacity(0.5))
    }

    // MARK: - Input Bar (Frosted Glass)

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Mic button
            Button(action: {
                Haptics.tap()
                showVoiceInput = true
            }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.fdTextMuted)
                    .frame(width: 36, height: 36)
            }

            // Text field
            HStack(spacing: 8) {
                TextField("Message Flow AI...", text: $inputText, axis: .vertical)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1...5)
                    .focused($isFocused)

                if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                LinearGradient(
                                    colors: [Color.fdAccent, Color.fdPurple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.fdBorder.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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

// MARK: - Modern Message Bubble

struct ModernMessageBubble: View {
    let message: AIMessage
    let onSuggestTap: (AISuggestion) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 60) }

            if !message.isUser {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.fdAccent, Color.fdPurple],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    if message.isUser {
                        Text(message.content)
                            .font(.fdBody)
                            .foregroundStyle(.white)
                    } else {
                        MarkdownTextView(text: message.content)
                    }

                    // Suggestion chips
                    if let suggestions = message.suggestions, !suggestions.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(suggestions) { suggestion in
                                Button(action: { onSuggestTap(suggestion) }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: suggestion.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(suggestion.text)
                                            .font(.fdMicro)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(message.isUser ? .white : Color.fdAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        message.isUser
                                            ? Color.white.opacity(0.2)
                                            : Color.fdAccent.opacity(0.1)
                                    )
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isUser
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color.fdAccent, Color.fdAccent.opacity(0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.fdSurface)
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: message.isUser ? 18 : 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: message.isUser ? 4 : 18,
                        topTrailingRadius: 18
                    )
                )
                .shadow(color: .black.opacity(0.04), radius: 3, y: 2)

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

// MARK: - Markdown Text View (simple renderer)

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("• ") || line.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdAccent)
                        renderInline(String(line.dropFirst(2)))
                    }
                } else if line.hasPrefix("**") && line.hasSuffix("**") {
                    Text(line.replacingOccurrences(of: "**", with: ""))
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                } else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(String(line[match]))
                            .font(.fdBody)
                            .foregroundStyle(Color.fdAccent)
                        renderInline(String(line[match.upperBound...]))
                    }
                } else {
                    renderInline(line)
                }
            }
        }
    }

    private func renderInline(_ text: String) -> some View {
        // Handle **bold** inline
        let parts = text.components(separatedBy: "**")
        return Group {
            if parts.count > 1 {
                parts.enumerated().reduce(Text("")) { result, item in
                    if item.offset % 2 == 1 {
                        return result + Text(item.element).bold()
                    } else {
                        return result + Text(item.element)
                    }
                }
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            } else {
                Text(text)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
            }
        }
    }
}

// MARK: - Modern Typing Indicator

struct ModernTypingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 4)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.fdTextMuted)
                        .frame(width: 7, height: 7)
                        .offset(y: sin(phase + Double(index) * 0.8) * 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fdSurface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 18
                )
            )
            .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

// MARK: - Modern Suggestion Pill

struct ModernSuggestionPill: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(text)
                    .font(.fdCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fdText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.fdSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.fdBorder.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        }
    }
}

// MARK: - Flow Layout (for suggestion chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    AIAssistantView()
}
