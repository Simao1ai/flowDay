// FocusScoreLockScreenWidget.swift
// FlowDay — Focus Score on the Lock Screen

import WidgetKit
import SwiftUI

// MARK: - Entry + Provider

struct FocusScoreEntry: TimelineEntry {
    let date: Date
    let score: Int
    let focusMinutes: Int
    let completedTasks: Int
    let totalTasks: Int
}

struct FocusScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusScoreEntry {
        FocusScoreEntry(date: .now, score: 72, focusMinutes: 50, completedTasks: 2, totalTasks: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusScoreEntry) -> Void) {
        let summary = WidgetSummary.load() ?? .placeholder
        completion(FocusScoreEntry(
            date: .now,
            score: summary.focusScore,
            focusMinutes: summary.focusMinutesToday,
            completedTasks: summary.completedTasks,
            totalTasks: summary.totalTasks
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusScoreEntry>) -> Void) {
        let summary = WidgetSummary.load() ?? .placeholder
        let entry = FocusScoreEntry(
            date: .now,
            score: summary.focusScore,
            focusMinutes: summary.focusMinutesToday,
            completedTasks: summary.completedTasks,
            totalTasks: summary.totalTasks
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget

struct FocusScoreLockScreenWidget: Widget {
    let kind = "FocusScoreLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusScoreProvider()) { entry in
            FocusScoreLockScreenView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Score")
        .description("Your daily focus score on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Views

struct FocusScoreLockScreenView: View {
    let entry: FocusScoreEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:    CircularScoreView(entry: entry)
        case .accessoryRectangular: RectangularScoreView(entry: entry)
        case .accessoryInline:      InlineScoreView(entry: entry)
        default:                    CircularScoreView(entry: entry)
        }
    }
}

// MARK: Circular

struct CircularScoreView: View {
    let entry: FocusScoreEntry

    var body: some View {
        Gauge(value: Double(entry.score), in: 0...100) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text("\(entry.score)")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeGradient)
    }

    private var gaugeGradient: Gradient {
        Gradient(colors: [WC.red, WC.yellow, WC.green])
    }
}

// MARK: Rectangular

struct RectangularScoreView: View {
    let entry: FocusScoreEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                Text("Focus Score")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(entry.score)")
                    .font(.caption.weight(.bold))
            }

            ProgressView(value: Double(entry.score), total: 100)
                .tint(scoreColor)
                .scaleEffect(x: 1, y: 1.5)

            HStack {
                Text("\(entry.completedTasks)/\(entry.totalTasks) tasks")
                    .font(.caption2)
                Spacer()
                Text("\(entry.focusMinutes)m focus")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var scoreColor: Color {
        switch entry.score {
        case 80...100: return WC.green
        case 60...79:  return WC.accent
        case 40...59:  return WC.yellow
        default:       return WC.red
        }
    }
}

// MARK: Inline

struct InlineScoreView: View {
    let entry: FocusScoreEntry

    var body: some View {
        Label("\(entry.score) score · \(entry.focusMinutes)m", systemImage: "bolt.fill")
    }
}
