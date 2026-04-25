// NotificationsSettingsView.swift
// FlowDay

import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskReminders = true
    @State private var habitReminders = true
    @State private var dailySummary = true
    @State private var summaryTime = "8:00 AM"

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Task reminders", isOn: $taskReminders, subtitle: "Get notified when it's time for your tasks.")
                        Divider().padding(.leading, 16)
                        FDSettingsUI.toggleRow(title: "Habit reminders", isOn: $habitReminders, subtitle: "Get notified to complete your habits.")
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Daily summary", isOn: $dailySummary, subtitle: "Receive a summary of your day at a set time.")
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Summary time", selection: $summaryTime, options: ["7:00 AM", "8:00 AM", "9:00 AM", "6:00 PM", "9:00 PM"])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }
}
