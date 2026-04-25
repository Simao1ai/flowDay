// ProductivitySettingsView.swift
// FlowDay

import SwiftUI

struct ProductivitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackProductivity = true
    @State private var dailyGoal = 5
    @State private var weeklyGoal = 30
    @State private var celebrateGoals = true
    @AppStorage("vacation_mode_enabled") private var vacationMode = false
    @State private var daysOff: Set<Int> = [0, 6]

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Track Productivity Score", isOn: $trackProductivity, subtitle: nil)
                    }

                    FDSettingsUI.sectionHeader("Set Goals")

                    FDSettingsUI.group {
                        HStack {
                            Text("Daily Task Goal")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Spacer()
                            Text("\(dailyGoal)")
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Weekly Task Goal")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Spacer()
                            Text("\(weeklyGoal)")
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Goal Celebrations", isOn: $celebrateGoals, subtitle: "Celebrate reaching daily and weekly task goals.")
                    }

                    FDSettingsUI.sectionHeader("Days Off")

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { day in
                                let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
                                Button {
                                    Haptics.pick()
                                    if daysOff.contains(day) {
                                        daysOff.remove(day)
                                    } else {
                                        daysOff.insert(day)
                                    }
                                } label: {
                                    Text(dayNames[day])
                                        .font(.fdCaptionBold)
                                        .foregroundStyle(daysOff.contains(day) ? .white : Color.fdText)
                                        .frame(width: 36, height: 36)
                                        .background(daysOff.contains(day) ? Color.fdAccent : Color.fdSurfaceHover)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Daily Task Goal streaks are paused on your days off.")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Vacation Mode", isOn: $vacationMode, subtitle: "When turned on, your streaks and Productivity Score will remain intact even if you don't achieve your goals.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Productivity")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }
}
