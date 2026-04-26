// NextTaskWidget.swift
// FlowDay — Shows the next upcoming task

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct NextTaskEntry: TimelineEntry {
    let date: Date
    let task: WidgetTask?
    let summary: WidgetSummary?
}

// MARK: - Provider

struct NextTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTaskEntry {
        NextTaskEntry(date: .now, task: .placeholder, summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTaskEntry) -> Void) {
        let summary = WidgetSummary.load() ?? .placeholder
        completion(NextTaskEntry(date: .now, task: summary.nextTask, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTaskEntry>) -> Void) {
        let summary = WidgetSummary.load()
        let entry = NextTaskEntry(date: .now, task: summary?.nextTask, summary: summary)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget

struct NextTaskWidget: Widget {
    let kind = "NextTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Task")
        .description("See your next upcoming task at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct NextTaskWidgetView: View {
    let entry: NextTaskEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let task = entry.task {
            switch family {
            case .systemSmall:  SmallNextTaskView(task: task)
            case .systemMedium: MediumNextTaskView(task: task, remaining: entry.summary?.upcomingTasks.dropFirst() ?? [])
            default:            SmallNextTaskView(task: task)
            }
        } else {
            NoTasksView()
        }
    }
}

// MARK: Small

struct SmallNextTaskView: View {
    let task: WidgetTask

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(WC.accent)
                Text("Up Next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WC.accent)
            }

            Spacer()

            // Priority indicator + title
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(WC.priorityColor(for: task.priorityRaw))
                    .frame(width: 3)
                    .frame(minHeight: 36)

                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Time + project
            VStack(alignment: .leading, spacing: 3) {
                if let time = task.displayTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(time, format: .dateTime.hour().minute())
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                if let project = task.projectName {
                    Text(project)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
    }
}

// MARK: Medium

struct MediumNextTaskView: View {
    let task: WidgetTask
    let remaining: ArraySlice<WidgetTask>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Main task
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(WC.accent)
                    Text("Up Next")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WC.accent)
                }

                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WC.priorityColor(for: task.priorityRaw))
                        .frame(width: 3, height: 50)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if let time = task.displayTime {
                                Label(time.formatted(.dateTime.hour().minute()), systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .labelStyle(CenteredLabelStyle())
                            }
                            if let mins = task.estimatedMinutes {
                                Label("\(mins)m", systemImage: "timer")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .labelStyle(CenteredLabelStyle())
                            }
                        }
                    }
                }

                if let project = task.projectName {
                    ProjectChip(name: project, colorHex: task.projectColorHex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Queue (next 2 tasks)
            if !remaining.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Also today")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(remaining.prefix(2))) { t in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(WC.priorityColor(for: t.priorityRaw))
                                .frame(width: 6, height: 6)
                            Text(t.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                    Spacer()
                }
                .frame(width: 110)
            }
        }
        .padding(12)
    }
}

// MARK: Empty

struct NoTasksView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(WC.green)
            Text("All clear!")
                .font(.subheadline.weight(.semibold))
            Text("No tasks scheduled")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Project Chip

struct ProjectChip: View {
    let name: String
    let colorHex: String?

    var chipColor: Color {
        guard let hex = colorHex else { return WC.accent }
        return hexColor(hex)
    }

    var body: some View {
        Text(name)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chipColor.opacity(0.15), in: Capsule())
            .foregroundStyle(chipColor)
    }

    private func hexColor(_ hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
