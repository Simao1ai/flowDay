// ThemeSettingsView.swift
// FlowDay

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @AppStorage("theme_sync") private var syncTheme = true

    private struct ThemeOption {
        let id: String
        let title: String
        let subtitle: String
        let accent: Color
        let preview: Color
        let isPro: Bool
    }

    private let freeThemes: [ThemeOption] = [
        ThemeOption(id: "Warm",      title: "Warm",      subtitle: "Default · warm orange",
                    accent: Color(hex: "D4713B"), preview: Color(hex: "FAF8F5"), isPro: false),
        ThemeOption(id: "Cool",      title: "Cool",      subtitle: "Blue-toned",
                    accent: Color(hex: "5B8FD4"), preview: Color(hex: "F4F6FA"), isPro: false),
        ThemeOption(id: "Dark",      title: "Dark",      subtitle: "True OLED black",
                    accent: Color(hex: "FF8C42"), preview: .black,              isPro: false),
    ]

    private let proThemes: [ThemeOption] = [
        ThemeOption(id: "Midnight",  title: "Midnight",  subtitle: "Pro",
                    accent: Color(hex: "8B6BBF"), preview: Color(hex: "1A1428"), isPro: true),
        ThemeOption(id: "Moonstone", title: "Moonstone", subtitle: "Pro",
                    accent: Color(hex: "9CA3AF"), preview: Color(hex: "F0F0F2"), isPro: true),
        ThemeOption(id: "Tangerine", title: "Tangerine", subtitle: "Pro",
                    accent: Color(hex: "FB923C"), preview: Color(hex: "FFF7ED"), isPro: true),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FDSettingsUI.group {
                    FDSettingsUI.toggleRow(title: "Sync Theme", isOn: $syncTheme,
                                           subtitle: "Sync your theme across devices")
                }

                FDSettingsUI.sectionHeader("THEMES")

                VStack(spacing: 12) {
                    ForEach(freeThemes, id: \.id) { option in
                        themeRow(option: option, isSelected: theme.themeID == option.id) {
                            Haptics.pick()
                            theme.themeID = option.id
                        }
                    }
                }

                FDSettingsUI.proUpsellCard(
                    icon: "star.fill",
                    title: "Unlock more themes",
                    message: "Get access to exclusive themes designed to inspire your productivity."
                )

                FDSettingsUI.sectionHeader("PRO THEMES")

                VStack(spacing: 12) {
                    ForEach(proThemes, id: \.id) { option in
                        themeRow(option: option, isSelected: theme.themeID == option.id) {
                            // Pro gating handled by ProAccessManager elsewhere; allow tap-to-preview.
                            Haptics.pick()
                            theme.themeID = option.id
                        }
                    }
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

    private func themeRow(option: ThemeOption, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(option.preview)
                        .frame(height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.fdBorderLight, lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 6)
                        .fill(option.accent)
                        .frame(height: 8)
                }
                .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                    Text(option.subtitle)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdGreen)
                } else if option.isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
