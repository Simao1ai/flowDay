// SyncStatusBadge.swift
// FlowDay
//
// Small glyph that lives in the toolbar. Tells the user whether their data
// has made it to Supabase. Prevents the "did my stuff save?" anxiety that
// silent-sync apps induce.

import SwiftUI

struct SyncStatusBadge: View {
    @State private var status = SyncStatusService.shared
    @State private var showTooltip = false

    var body: some View {
        Button {
            showTooltip = true
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating, isActive: isSyncing)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
                .accessibilityLabel(accessibilityLabel)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTooltip, arrowEdge: .top) {
            tooltipContent
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Presentation

    private var isSyncing: Bool {
        if case .syncing = status.state { return true }
        return false
    }

    private var iconName: String {
        switch status.state {
        case .idle:         "cloud"
        case .syncing:      "arrow.triangle.2.circlepath"
        case .synced:       "checkmark.icloud"
        case .offline:      "icloud.slash"
        case .error:        "exclamationmark.icloud"
        }
    }

    private var tint: Color {
        switch status.state {
        case .idle:         .fdTextMuted
        case .syncing:      .fdBlue
        case .synced:       .fdGreen
        case .offline:      .fdTextMuted
        case .error:        .fdRed
        }
    }

    private var accessibilityLabel: String {
        switch status.state {
        case .idle:             "Sync idle"
        case .syncing:          "Syncing to cloud"
        case .synced(let at):   "Last synced \(at.formatted(.relative(presentation: .named)))"
        case .offline:          "Offline"
        case .error(let msg):   "Sync error: \(msg)"
        }
    }

    // MARK: - Tooltip

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundStyle(tint)
                Text(tooltipHeadline)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
            }
            Text(tooltipDetail)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .padding(12)
        .frame(minWidth: 220)
    }

    private var tooltipHeadline: String {
        switch status.state {
        case .idle:         "Ready"
        case .syncing:      "Syncing…"
        case .synced:       "Up to date"
        case .offline:      "Offline"
        case .error:        "Sync failed"
        }
    }

    private var tooltipDetail: String {
        switch status.state {
        case .idle:
            "Your changes will sync when you make one."
        case .syncing:
            "Saving changes to the cloud."
        case .synced(let at):
            "Last synced \(at.formatted(.relative(presentation: .named)))."
        case .offline:
            "Changes are saved locally and will sync when you're back online."
        case .error(let msg):
            "Couldn't reach the cloud. \(msg)"
        }
    }
}
