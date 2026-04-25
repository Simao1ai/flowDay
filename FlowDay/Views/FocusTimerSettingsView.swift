// FocusTimerSettingsView.swift
// FlowDay — Focus Timer configuration
//
// Writes to the same UserDefaults keys that FocusTimerService reads,
// so changes take effect on the next session start.

import SwiftUI

struct FocusTimerSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("focus_work_minutes") private var workMinutes: Int = 25
    @AppStorage("focus_short_break_minutes") private var shortBreakMinutes: Int = 5
    @AppStorage("focus_long_break_minutes") private var longBreakMinutes: Int = 15

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    durationsSection
                    infoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fdText)
                            .frame(width: 36, height: 36)
                            .background(Color.fdSurfaceHover)
                            .clipShape(Circle())
                    }
                }
            }
    }

    // MARK: - Sections

    private var durationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Durations")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                stepperRow("Focus", value: $workMinutes, range: 5...120, unit: "min")
                Divider().padding(.leading, 16)
                stepperRow("Short Break", value: $shortBreakMinutes, range: 1...30, unit: "min")
                Divider().padding(.leading, 16)
                stepperRow("Long Break", value: $longBreakMinutes, range: 5...60, unit: "min")
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private var infoSection: some View {
        Text("Classic Pomodoro: 25 min focus → 5 min break, × 4, then 15 min long break. Changes take effect on the next session.")
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Row

    private func stepperRow(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        Haptics.tap()
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            value.wrappedValue > range.lowerBound
                                ? Color.fdAccent
                                : Color.fdTextMuted.opacity(0.3)
                        )
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue) \(unit)")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                    .frame(minWidth: 56, alignment: .center)
                    .monospacedDigit()

                Button {
                    if value.wrappedValue < range.upperBound {
                        Haptics.tap()
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            value.wrappedValue < range.upperBound
                                ? Color.fdAccent
                                : Color.fdTextMuted.opacity(0.3)
                        )
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
