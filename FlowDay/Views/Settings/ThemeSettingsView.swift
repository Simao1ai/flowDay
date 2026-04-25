// ThemeSettingsView.swift
// FlowDay

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selected_theme") private var selectedTheme = "FlowDay"
    @AppStorage("theme_sync") private var syncTheme = true
    @AppStorage("theme_auto_dark_mode") private var autoDarkMode = false

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Sync Theme", isOn: $syncTheme, subtitle: "Sync your theme across devices")
                        Divider().padding(.leading, 16)
                        FDSettingsUI.toggleRow(title: "Auto Dark Mode", isOn: $autoDarkMode, subtitle: "Sync with your device's Dark Mode")
                    }

                    VStack(spacing: 12) {
                        themeListItem(name: "FlowDay", accentColor: Color.fdAccent, isSelected: selectedTheme == "FlowDay")
                            .onTapGesture { Haptics.pick(); selectedTheme = "FlowDay" }
                        themeListItem(name: "Midnight", accentColor: Color(hex: "2A2A3E"), isSelected: selectedTheme == "Midnight")
                            .onTapGesture { Haptics.pick(); selectedTheme = "Midnight" }
                        themeListItem(name: "Moonstone", accentColor: Color(hex: "9CA3AF"), isSelected: selectedTheme == "Moonstone")
                            .onTapGesture { Haptics.pick(); selectedTheme = "Moonstone" }
                        themeListItem(name: "Tangerine", accentColor: Color(hex: "FB923C"), isSelected: selectedTheme == "Tangerine")
                            .onTapGesture { Haptics.pick(); selectedTheme = "Tangerine" }
                    }

                    FDSettingsUI.proUpsellCard(icon: "star.fill", title: "Unlock more themes", message: "Get access to exclusive themes designed to inspire your productivity.")

                    FDSettingsUI.sectionHeader("PRO THEMES")

                    VStack(spacing: 12) {
                        proThemeListItem(name: "Lavender")
                        proThemeListItem(name: "Blueberry")
                        proThemeListItem(name: "Kale")
                        proThemeListItem(name: "Raspberry")
                        proThemeListItem(name: "Sage")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }

    private func themeListItem(name: String, accentColor: Color, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.fdAccentLight : Color.fdSurfaceHover)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 6)
                    .fill(accentColor.opacity(0.5))
                    .frame(height: 8)
            }
            .frame(width: 50)

            Text(name)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fdGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func proThemeListItem(name: String) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fdSurfaceHover)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.fdBorder)
                    .frame(height: 8)
            }
            .frame(width: 50)

            Text(name)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
