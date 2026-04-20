// WhatsNewView.swift
// FlowDay
//
// Changelog browser. Each entry highlights what shipped in a release with
// an icon, headline, and short copy. New entries get added at the top of
// the static `releases` array — that's the whole maintenance flow.

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

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
            version: "1.2.0", date: "Apr 2026", isLatest: true,
            entries: [
                .init(icon: "waveform", tint: .fdAccent,
                      title: "Ramble — dictate multiple tasks at once",
                      detail: "Speak a stream of tasks; FlowDay parses each one with dates, projects, priority, duration, and labels. Free."),
                .init(icon: "checklist", tint: .fdBlue,
                      title: "Multi-select",
                      detail: "Long-press any task to enter selection mode. Complete, reschedule, or delete in batches."),
                .init(icon: "leaf.fill", tint: .fdGreen,
                      title: "Energy-aware empty states",
                      detail: "When your day is clear, FlowDay tailors the suggestion to your logged energy level."),
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
                .init(icon: "ipad", tint: .fdPurple,
                      title: "iPad & landscape support",
                      detail: "FlowDay now rotates and runs in Slide Over / Split View on iPad."),
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
