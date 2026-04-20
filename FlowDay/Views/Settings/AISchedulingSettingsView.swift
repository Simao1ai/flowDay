// AISchedulingSettingsView.swift
// FlowDay

import SwiftUI

struct AISchedulingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = true
    @State private var peakStart = "8:00 AM"
    @State private var peakEnd = "12:00 PM"
    @State private var respectCalendar = true
    @State private var autoSuggest = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "AI scheduling enabled", isOn: $enabled, subtitle: nil)
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Peak focus start", selection: $peakStart, options: ["7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Peak focus end", selection: $peakEnd, options: ["11:00 AM", "12:00 PM", "1:00 PM", "2:00 PM"])
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Respect calendar events", isOn: $respectCalendar, subtitle: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.toggleRow(title: "Auto-suggest on new tasks", isOn: $autoSuggest, subtitle: nil)
                    }

                    FDSettingsUI.infoCard(
                        icon: "sparkles",
                        title: "Energy-Aware AI",
                        message: "FlowDay schedules your hardest tasks during peak energy hours and lighter tasks when you're winding down."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("AI Scheduling")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }
}
