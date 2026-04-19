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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.fdSurfaceHover)
                .cornerRadius(16)
                .lineLimit(1)
        }
    }
}
