// RemindersSettingsView.swift
// FlowDay

import SwiftUI

struct RemindersSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.proUpsellBanner(
                        icon: "star.fill",
                        title: "Smart reminders included",
                        message: "Free accounts get reminders at task time. FlowDay includes smart reminders that factor in task duration."
                    )

                    FDSettingsUI.sectionHeader("Preferences")

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Remind Me Via", subtitle: nil, value: "Push Notifications")
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "When Snoozed...", subtitle: nil, value: "15 minutes")
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Automatic Reminders", subtitle: "When enabled, a reminder before the task's due time will be added by default.", value: "At time of task")
                    }

                    FDSettingsUI.sectionHeader("REMINDERS NOT WORKING?", color: Color.fdRed)

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Enable Time-Sensitive Notifications", subtitle: "Required for notifications to appear on lock screen.", value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Enable Background App Refresh", subtitle: "Allows FlowDay to process reminders even when closed.", value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Troubleshoot Notifications", subtitle: nil, value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }
}
