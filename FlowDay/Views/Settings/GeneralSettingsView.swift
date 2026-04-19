// GeneralSettingsView.swift
// FlowDay

import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var homeView = "Today"
    @State private var syncHomeView = true
    @State private var smartDateRecognition = true
    @State private var resetSubTasks = false
    @State private var timezone = "Auto"
    @State private var startWeekOn = "Monday"
    @State private var interpretNextWeek = "Monday"
    @State private var interpretWeekend = "Saturday"
    @State private var openWebLinksIn = "FlowDay"
    @State private var rightSwipe = "Reschedule"
    @State private var leftSwipe = "Complete"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Home View", selection: $homeView, options: ["Today", "Upcoming", "Inbox"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.toggleRow(title: "Sync Home View", isOn: $syncHomeView, subtitle: "When turned on, your Home view will be the same on all platforms.")
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Smart Date Recognition", isOn: $smartDateRecognition, subtitle: "Detect dates in tasks automatically")
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Reset Sub-Tasks", isOn: $resetSubTasks, subtitle: "Reset sub-tasks when you complete a recurring task.")
                    }

                    FDSettingsUI.sectionHeader("Date & Time")
                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Timezone", selection: $timezone, options: ["Auto", "UTC", "EST", "PST", "CST", "GMT"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Start Week On", selection: $startWeekOn, options: ["Sunday", "Monday", "Saturday"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Interpret \"Next Week\" As", selection: $interpretNextWeek, options: ["Monday", "Tuesday"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Interpret \"Weekend\" As", selection: $interpretWeekend, options: ["Saturday", "Friday"])
                    }

                    FDSettingsUI.sectionHeader("App Settings")
                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Open Web Links In", selection: $openWebLinksIn, options: ["FlowDay", "Safari", "Chrome"])
                    }

                    FDSettingsUI.sectionHeader("Sound")
                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Task Complete Tone", subtitle: nil, value: "Default")
                    }

                    FDSettingsUI.sectionHeader("Swipe Actions")
                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Right Swipe", selection: $rightSwipe, options: ["Reschedule", "Complete", "Delete"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Left Swipe", selection: $leftSwipe, options: ["Complete", "Delete", "Schedule"])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("General")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }
}
