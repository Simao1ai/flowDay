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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    ForEach(Self.releases) { release in
                        releaseSection(release)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
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
                .init(icon: "text.bubble", tint: .fdAccent,
                      title: "Natural Language Commands",
                      detail: "Tell Flow AI to reschedule, complete, delete, or reprioritize tasks using plain English."),
                .init(icon: "sparkles", tint: .fdPurple,
                      title: "Modernized Flow AI Chat",
                      detail: "Redesigned chat with frosted input bar, animated typing indicator, and markdown rendering."),
                .init(icon: "chart.line.uptrend.xyaxis", tint: .fdGreen,
                      title: "Focus Score",
                      detail: "A daily 0-100 score combining tasks, focus time, habits, and energy alignment. Track your 30-day trend."),
                .init(icon: "calendar.badge.clock", tint: .fdBlue,
                      title: "AI Auto-Schedule",
                      detail: "One tap to have AI build your optimal weekly schedule around energy levels and calendar events.")
            ]
        ),
        .init(
            version: "1.2.0", date: "Apr 2026", isLatest: false,
            entries: [
                .init(icon: "sun.max.fill", tint: .fdYellow,
                      title: "Daily Brief",
                      detail: "A morning AI briefing card at the top of Today — your priorities, energy tip, and schedule at a glance."),
                .init(icon: "star.circle.fill", tint: .fdAccent,
                      title: "Gamification & XP",
                      detail: "Earn XP for tasks, habits, and focus sessions. Level up, maintain streaks, and unlock 9 achievement badges."),
                .init(icon: "waveform", tint: .fdAccent,
                      title: "Ramble — dictate multiple tasks at once",
                      detail: "Speak a stream of tasks; FlowDay parses each one with dates, projects, priority, duration, and labels."),
                .init(icon: "checkmark.icloud.fill", tint: .fdGreen,
                      title: "Sync transparency",
                      detail: "An explicit timestamp in Settings tells you exactly when your data last reached the cloud.")
            ]
        ),
        .init(
            version: "1.1.0", date: "Apr 2026", isLatest: false,
            entries: [
                .init(icon: "rectangle.split.3x1", tint: .fdAccent,
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
