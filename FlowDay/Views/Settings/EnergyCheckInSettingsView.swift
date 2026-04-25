// EnergyCheckInSettingsView.swift
// FlowDay

import SwiftUI

struct EnergyCheckInSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("energy_checkin_enabled") private var enabled = true
    @AppStorage("energy_checkin_frequency") private var frequency = "Daily"
    @AppStorage("energy_checkin_time") private var checkInTime = "Morning"

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Energy check-in enabled", isOn: $enabled, subtitle: nil)
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.pickerRow(title: "Frequency", selection: $frequency, options: ["Daily", "Weekdays only", "Manual"])
                        Divider().padding(.leading, 16)
                        FDSettingsUI.pickerRow(title: "Check-in time", selection: $checkInTime, options: ["Morning", "When I open the app", "Custom time"])
                    }

                    FDSettingsUI.infoCard(
                        icon: "bolt.fill",
                        title: "Why Energy Matters",
                        message: "Your energy level changes how the AI schedules your day. High energy means harder tasks get front-loaded."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Energy Check-in")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }
}
