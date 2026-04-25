// WhatsNewView.swift
// FlowDay
//
// Changelog browser. Each entry highlights what shipped in a release with
// an icon, headline, and short copy. New entries get added at the top of
// the static `releases` array — that's the whole maintenance flow.

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastSeenAppVersion") private var lastSeenVersion: String = ""

    /// The current app version from the bundle
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Whether the user hasn't seen the current version yet
    static var hasUnseenUpdate: Bool {
        let last = UserDefaults.standard.string(forKey: "lastSeenAppVersion") ?? ""
        return last != currentVersion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                ForEach(Self.releases) { release in
                    releaseSection(release)
                }
            }
            .onDisappear {
                lastSeenVersion = Self.currentVersion
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color.fdAccent, Color.fdPurple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Always shipping")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Color.fdText)
            Text("Here's what's new in FlowDay.")
                .font(.fdBody)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Release section

    private func releaseSection(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(release.version)
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                Text(release.date)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                Spacer()
                if release.isLatest {
                    Text("New")
                        .font(.fdMicroBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.fdAccent)
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(release.entries.enumerated()), id: \.offset) { index, entry in
                    entryRow(entry)
                    if index < release.entries.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func entryRow(_ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: entry.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entry.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Text(entry.detail)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
            }
            Spacer()
        }
        .padding(14)
    }
}

// MARK: - Release Data

extension WhatsNewView {

    struct Release: Identifiable {
        let id = UUID()
        let version: String
        let date: String
        let isLatest: Bool
        let entries: [Entry]
    }

    struct Entry {
        let icon: String
        let tint: Color
        let title: String
        let detail: String
    }

    static let releases: [Release] = [
        .init(
            version: "1.3.0", date: "Apr 2026", isLatest: true,
            entries: [
                .init(icon: "text.bubble.fill", tint: .fdAccent,
                      title: "Natural Language Commands",
                      detail: "Tell Flow AI \"Move my dentist to Tuesday\" or \"Mark grocery shopping as done\" — it understands and executes."),
                .init(icon: "calendar.badge.clock", tint: .fdBlue,
                      title: "AI Meeting Prep",
                      detail: "30 minutes before a meeting, FlowDay auto-generates talking points, questions, and context. Pro feature."),
                .init(icon: "bubble.left.and.bubble.right.fill", tint: .fdPurple,
                      title: "Flow AI Redesign",
                      detail: "Frosted glass input bar, markdown rendering in responses, and a smoother chat experience overall.")
            ]
        ),
        .init(
            version: "1.2.0", date: "Apr 2026", isLatest: false,
            entries: [
                .init(icon: "sparkles.rectangle.stack", tint: .fdAccent,
                      title: "AI Auto-Schedule",
                      detail: "Tap \"Auto-Schedule\" on any day and the AI fills your timeline around your calendar and energy level."),
                .init(icon: "chart.xyaxis.line", tint: .fdGreen,
                      title: "Focus Score",
                      detail: "A daily 0–100 score that weighs tasks completed, deep work sessions, and streak consistency."),
                .init(icon: "chart.bar.doc.horizontal", tint: .fdBlue,
                      title: "Weekly AI Report",
                      detail: "Every Sunday, get an AI-written recap of your week with trends and suggestions for next week."),
                .init(icon: "waveform", tint: .fdYellow,
                      title: "Ramble — dictate multiple tasks",
                      detail: "Speak a stream of tasks; FlowDay parses each one with dates, projects, priority, and labels. Free.")
            ]
        ),
        .init(
            version: "1.1.0", date: "Apr 2026", isLatest: false,
            entries: [
                .init(icon: "brain.head.profile", tint: .fdAccent,
                      title: "Smart Daily Brief",
                      detail: "Wake up to an AI-written summary of your day: priorities, energy tip, and one focus task."),
                .init(icon: "star.circle.fill", tint: .fdYellow,
                      title: "Gamification & XP",
                      detail: "Earn XP for completing tasks, maintaining streaks, and deep-work sessions. Level up over time."),
                .init(icon: "rectangle.split.3x1", tint: .fdPurple,
                      title: "Kanban board view",
                      detail: "Toggle any project between list and board. Drag tasks across section columns."),
                .init(icon: "line.3.horizontal.decrease.circle", tint: .fdBlue,
                      title: "Smart filters",
                      detail: "Today, Overdue, This Week, No Date, Priority 1, and more — surfaced from Browse."),
                .init(icon: "timer", tint: .fdAccent,
                      title: "Focus Timer",
                      detail: "Built-in Pomodoro timer with customizable work/break intervals, background support, and session tracking."),
                .init(icon: "mic.fill", tint: .fdYellow,
                      title: "Siri Shortcuts",
                      detail: "Say \"Add a task to FlowDay\" or \"How many FlowDay tasks do I have left\" from anywhere.")
            ]
        ),
        .init(
            version: "1.0.0", date: "Apr 2026", isLatest: false,
            entries: [
                .init(icon: "sparkles", tint: .fdAccent,
                      title: "Hello, FlowDay",
                      detail: "Energy-aware AI day planner, two-way calendar sync, habits, focus sessions, and unlimited free projects.")
            ]
        )
    ]
}
