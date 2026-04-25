// MessageBubble.swift
// FlowDay
//
// Chat primitives: the bubble that renders a single AIMessage, the
// three-dot typing indicator shown while Flow AI thinks, and the small
// pill used for the welcome screen's suggested prompts.

import SwiftUI

struct MessageBubble: View {
    let message: AIMessage
    let onSuggestTap: (AISuggestion) -> Void

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.isUser { Spacer(minLength: 48) }

                if !message.isUser {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    if message.isUser {
                        Text(message.content)
                            .font(.fdBody)
                            .foregroundColor(.white)
                    } else {
                        markdownText(message.content)
                            .font(.fdBody)
                            .foregroundColor(.fdText)
                    }

                    if let suggestions = message.suggestions, !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(suggestions) { suggestion in
                                Button(action: { onSuggestTap(suggestion) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: suggestion.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(suggestion.text)
                                            .font(.fdCaption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(message.isUser ? .white : .fdAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        message.isUser ?
                                        Color.white.opacity(0.2) :
                                        Color.fdAccentLight
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
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: message.isUser ? 4 : 18
                    )
                )
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                if !message.isUser { Spacer(minLength: 48) }
            }

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.fdMicro)
                .foregroundColor(.fdTextMuted)
                .padding(.horizontal, message.isUser ? 4 : 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func markdownText(_ content: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(content)
        }
    }
}

struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.fdTextSecondary)
                        .frame(width: 7, height: 7)
                        .offset(y: phase == index ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
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
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .onAppear { phase = 0 }
    }
}

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
                .foregroundColor(.fdText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.fdBorder, lineWidth: 0.5))
                .lineLimit(1)
        }
    }
}
