// MessageBubble.swift
// FlowDay
//
// Modern chat primitives inspired by ChatGPT / Apple Intelligence:
// • User messages  — right-aligned, fdAccent fill, rounded pill shape
// • AI messages    — left-aligned, fdSurface fill, sparkles avatar
// • Typing indicator — three bouncing dots with staggered animation
// • QuickSuggestionChip — frosted pill for the welcome screen

import SwiftUI

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    let onSuggestTap: (AISuggestion) -> Void

    @State private var showCopyConfirm = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.isUser { Spacer(minLength: UIScreen.main.bounds.width * 0.20) }

                if !message.isUser { aiAvatar }

                bubbleContent
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.80, alignment: message.isUser ? .trailing : .leading)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            showCopyConfirm = true
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                if !message.isUser { Spacer(minLength: UIScreen.main.bounds.width * 0.20) }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Avatar

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Bubble

    private var bubbleContent: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            SimpleMarkdownText(message.content)
                .font(.fdBody)
                .foregroundStyle(message.isUser ? .white : Color.fdText)

            if let suggestions = message.suggestions, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestions) { suggestion in
                        Button(action: { onSuggestTap(suggestion) }) {
                            HStack(spacing: 6) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(suggestion.text)
                                    .font(.fdCaption)
                            }
                            .foregroundStyle(message.isUser ? .white : Color.fdAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                message.isUser ? Color.white.opacity(0.2) : Color.fdAccentLight
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(message.isUser ? Color.fdAccent : Color.fdSurface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: message.isUser ? 18 : 4,
                bottomLeadingRadius: message.isUser ? 18 : 18,
                bottomTrailingRadius: message.isUser ? 4 : 18,
                topTrailingRadius: 18
            )
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Simple Markdown Renderer

struct SimpleMarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.fdTextMuted)
                        .frame(width: 7, height: 7)
                        .offset(y: phase == i ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: phase
                        )
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
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

            Spacer(minLength: UIScreen.main.bounds.width * 0.20)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation { phase = 0 }
        }
    }
}

// MARK: - Quick Suggestion Chip

struct QuickSuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(text)
                .font(.fdCaption)
                .foregroundStyle(Color.fdText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .lineLimit(1)
        }
    }
}

// MARK: - Timestamp Label

struct MessageTimestampLabel: View {
    let date: Date

    var body: some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.fdMicro)
            .foregroundStyle(Color.fdTextMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}
