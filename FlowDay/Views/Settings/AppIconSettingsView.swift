// AppIconSettingsView.swift
// FlowDay

import SwiftUI

struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIcon = "FlowDay"

    struct AppIconOption: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let gradient: [Color]
        let overlayIcon: String
        let overlayLetter: String?
        let isPro: Bool
    }

    private var freeIcons: [AppIconOption] {
        [
            AppIconOption(name: "FlowDay", subtitle: "Classic warm", gradient: [Color.fdAccent, Color.fdAccentSoft], overlayIcon: "sparkles", overlayLetter: "F", isPro: false),
            AppIconOption(name: "Midnight", subtitle: "Dark mode", gradient: [Color(hex: "1A1A2E"), Color(hex: "3D3D5C")], overlayIcon: "moon.stars.fill", overlayLetter: "F", isPro: false),
            AppIconOption(name: "Ocean", subtitle: "Cool & calm", gradient: [Color(hex: "2563EB"), Color(hex: "60A5FA")], overlayIcon: "water.waves", overlayLetter: "F", isPro: false),
            AppIconOption(name: "Sunset", subtitle: "Warm glow", gradient: [Color(hex: "F97316"), Color(hex: "EC4899")], overlayIcon: "sun.horizon.fill", overlayLetter: "F", isPro: false),
            AppIconOption(name: "Forest", subtitle: "Natural", gradient: [Color(hex: "059669"), Color(hex: "34D399")], overlayIcon: "leaf.fill", overlayLetter: "F", isPro: false),
        ]
    }

    private var proIcons: [AppIconOption] {
        [
            AppIconOption(name: "Blueberry", subtitle: "Bold purple", gradient: [Color(hex: "7C3AED"), Color(hex: "A78BFA")], overlayIcon: "bolt.fill", overlayLetter: "F", isPro: true),
            AppIconOption(name: "Coral", subtitle: "Vibrant pink", gradient: [Color(hex: "EC4899"), Color(hex: "FB7185")], overlayIcon: "heart.fill", overlayLetter: "F", isPro: true),
            AppIconOption(name: "Gold", subtitle: "Premium feel", gradient: [Color(hex: "D4A73B"), Color(hex: "F5D76E")], overlayIcon: "star.fill", overlayLetter: "F", isPro: true),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let current = freeIcons.first(where: { $0.name == selectedIcon }) {
                        currentIconPreview(current)
                    }

                    FDSettingsUI.sectionHeader("FREE ICONS")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(freeIcons) { icon in
                            iconGridItem(icon: icon, isSelected: selectedIcon == icon.name)
                                .onTapGesture {
                                    Haptics.pick()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedIcon = icon.name
                                    }
                                }
                        }
                    }

                    FDSettingsUI.proUpsellCard(icon: "star.fill", title: "Unlock all icons", message: "Get exclusive icon designs with FlowDay Pro.")

                    FDSettingsUI.sectionHeader("PRO ICONS")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(proIcons) { icon in
                            iconGridItem(icon: icon, isSelected: false)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }

    private func currentIconPreview(_ icon: AppIconOption) -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: icon.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .overlay(
                    ZStack {
                        Text(icon.overlayLetter ?? "")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: icon.overlayIcon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .offset(x: 26, y: -26)
                    }
                )
                .shadow(color: icon.gradient.first?.opacity(0.4) ?? .clear, radius: 12, y: 6)

            Text(icon.name)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Text("Current icon")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func iconGridItem(icon: AppIconOption, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: icon.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .overlay(
                        ZStack {
                            Text(icon.overlayLetter ?? "")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Image(systemName: icon.overlayIcon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .offset(x: 18, y: -18)
                        }
                    )
                    .shadow(color: icon.gradient.first?.opacity(0.2) ?? .clear, radius: 6, y: 3)

                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.fdGreen, lineWidth: 3)
                        .frame(width: 72, height: 72)
                }

                if icon.isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .offset(x: 24, y: 24)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.fdGreen)
                        .background(Circle().fill(.white).frame(width: 14, height: 14))
                        .offset(x: 24, y: -24)
                }
            }

            VStack(spacing: 2) {
                Text(icon.name)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                Text(icon.subtitle)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
