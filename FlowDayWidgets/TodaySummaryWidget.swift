// TodaySummaryWidget.swift
// FlowDay — Today's task progress + focus time

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TodaySummaryEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
}

// MARK: - Provider

struct TodaySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySummaryEntry {
        TodaySummaryEntry(date: .now, summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySummaryEntry) -> Void) {
        let summary = WidgetSummary.load() ?? .placeholder
        completion(TodaySummaryEntry(date: .now, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySummaryEntry>) -> Void) {
        let summary = WidgetSummary.load() ?? .placeholder
        let entry = TodaySummaryEntry(date: .now, summary: summary)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget

struct TodaySummaryWidget: Widget {
    let kind = "TodaySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySummaryProvider()) { entry in
            TodaySummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today Summary")
        .description("Track today's task progress and focus time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TodaySummaryWidgetView: View {
    let entry: TodaySummaryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallTodaySummaryView(summary: entry.summary)
        case .systemMedium: MediumTodaySummaryView(summary: entry.summary)
        default:            SmallTodaySummaryView(summary: entry.summary)
        }
    }
}

// MARK: Small

struct SmallTodaySummaryView: View {
    let summary: WidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Circle()
                    .fill(WC.accent)
                    .frame(width: 6, height: 6)
                Text("Today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WC.accent)
                Spacer()
                Text(Date.now, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Completion ring
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: summary.completionRate)
                        .stroke(
                            summary.completionRate >= 1 ? WC.green : WC.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: summary.completionRate)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.completedTasks)/\(summary.totalTasks)")
                        .font(.headline.weight(.bold))
                    Text("tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Focus minutes
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(WC.accent)
                Text("\(summary.focusMinutesToday)m focus")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

// MARK: Medium

struct MediumTodaySummaryView: View {
    let summary: WidgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if summary.focusScore > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(summary.focusScore)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(scoreColor)
                        Text("score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Progress bar
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("\(summary.completedTasks) of \(summary.totalTasks) tasks")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text("\(Int(summary.completionRate * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(summary.completionRate >= 1 ? WC.green : WC.accent)
                            .frame(width: geo.size.width * summary.completionRate)
                    }
                }
                .frame(height: 5)
            }

            // Stats row
            HStack(spacing: 12) {
                Label("\(summary.focusMinutesToday)m", systemImage: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(CenteredLabelStyle())

                if summary.focusSessionsToday > 0 {
                    Label("\(summary.focusSessionsToday) sessions", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(CenteredLabelStyle())
                }

                if let energy = summary.energyLevel {
                    Spacer()
                    Text(energyEmoji(energy))
                        .font(.caption)
                }
            }

            // Next task
            if let next = summary.nextTask {
                Divider()
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WC.priorityColor(for: next.priorityRaw))
                        .frame(width: 3, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if let time = next.displayTime {
                            Text(time, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
    }

    private var scoreColor: Color {
        switch summary.focusScore {
        case 80...100: return WC.green
        case 60...79:  return WC.accent
        case 40...59:  return WC.yellow
        default:       return WC.red
        }
    }

    private func energyEmoji(_ level: String) -> String {
        switch level {
        case "high":   return "⚡"
        case "normal": return "☀️"
        case "low":    return "🌙"
        default:       return ""
        }
    }
}

// MARK: - Helpers

struct CenteredLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
