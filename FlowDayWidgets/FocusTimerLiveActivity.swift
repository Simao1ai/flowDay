// FocusTimerLiveActivity.swift
// FlowDay — Focus Timer Live Activity with Dynamic Island

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct FocusTimerLiveActivity: Widget {
    let kind = "FocusTimerLiveActivity"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerAttributes.self) { context in
            // Lock screen / notification banner
            FocusTimerBannerView(context: context)
                .containerBackground(
                    context.state.isBreak
                        ? Color(red: 0.357, green: 0.561, blue: 0.831).opacity(0.15)
                        : Color(red: 0.831, green: 0.443, blue: 0.231).opacity(0.15),
                    for: .widget
                )

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                            .font(.title3)
                            .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(context.state.sessionType)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)
                            if let task = context.state.taskTitle {
                                Text(task)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)
                            .frame(width: 70, alignment: .trailing)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedTimerProgressView(context: context)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }

            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)

            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)
                    .frame(width: 40)

            } minimal: {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(context.state.isBreak ? WC.blue : WC.accent)
                    .frame(width: 36)
            }
        }
    }
}

// MARK: - Lock Screen Banner

struct FocusTimerBannerView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var accentColor: Color {
        context.state.isBreak ? WC.blue : WC.accent
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.sessionType)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                if let task = context.state.taskTitle {
                    Text(task)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Countdown
            VStack(alignment: .trailing, spacing: 2) {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(accentColor)
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Expanded Progress Bar

struct ExpandedTimerProgressView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var accentColor: Color {
        context.state.isBreak ? WC.blue : WC.accent
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(context.state.sessionType)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(context.state.endTime, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
