// CalendarSettingsView.swift
// FlowDay

import SwiftUI

struct CalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarAccountManager.self) private var accountManager
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: CalendarProvider? = nil

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    if !accountManager.connectedAccounts.isEmpty {
                        connectedSection
                    }

                    connectSection

                    if let error = accountManager.connectionError {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    Text("Connect your calendar accounts to see all your events in FlowDay. Your schedule helps the AI planner find the best time slots for your tasks.")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .multilineTextAlignment(.center)

                    FDSettingsUI.sectionHeader("WHAT YOU CAN DO")

                    VStack(spacing: 12) {
                        calendarFeatureCard(
                            icon: "calendar",
                            title: "Unified Calendar View",
                            description: "See events from Apple, Google, and Outlook calendars together in Today and Upcoming."
                        )
                        calendarFeatureCard(
                            icon: "sparkles",
                            title: "AI-Powered Scheduling",
                            description: "Flow AI reads your calendar to find free slots and avoid double-booking when planning your day."
                        )
                        calendarFeatureCard(
                            icon: "calendar.badge.plus",
                            title: "Two-Way Sync",
                            description: "Time-blocked tasks appear on your calendar so colleagues see you're busy."
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Calendar Accounts")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
            .alert("Disconnect Calendar", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { providerToDisconnect = nil }
                Button("Disconnect", role: .destructive) {
                    if let provider = providerToDisconnect {
                        accountManager.disconnect(provider)
                    }
                    providerToDisconnect = nil
                }
            } message: {
                if let provider = providerToDisconnect {
                    Text("Are you sure you want to disconnect \(provider.displayName)? Events from this account will no longer appear in FlowDay.")
                }
            }
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                ForEach(Array(accountManager.connectedAccounts.enumerated()), id: \.element.id) { index, account in
                    connectedAccountRow(account: account)
                    if index < accountManager.connectedAccounts.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func connectedAccountRow(account: CalendarAccount) -> some View {
        HStack(spacing: 12) {
            providerIcon(account.provider)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.provider.displayName)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Text(account.email)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Button {
                providerToDisconnect = account.provider
                showDisconnectAlert = true
            } label: {
                Text("Disconnect")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.fdRedLight)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Calendar Account")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                let availableProviders = CalendarProvider.allCases.filter { provider in
                    !accountManager.isConnected(provider)
                }

                if availableProviders.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.fdGreen)
                        Text("All calendar accounts connected")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                    .padding(16)
                } else {
                    ForEach(Array(availableProviders.enumerated()), id: \.element.id) { index, provider in
                        connectProviderRow(provider: provider)
                        if index < availableProviders.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    private func connectProviderRow(provider: CalendarProvider) -> some View {
        Button {
            connectProvider(provider)
        } label: {
            HStack(spacing: 12) {
                providerIcon(provider)

                Text("Connect \(provider.displayName)")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                if accountManager.isConnecting == provider {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .disabled(accountManager.isConnecting != nil)
    }

    private func providerIcon(_ provider: CalendarProvider) -> some View {
        Group {
            switch provider {
            case .apple:
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.fdText)
            case .google:
                Text("G")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .microsoft:
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(providerColor(provider))
        )
    }

    private func providerColor(_ provider: CalendarProvider) -> Color {
        switch provider {
        case .apple: Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }).opacity(0.85)
        case .google: Color(hex: "4285F4")
        case .microsoft: Color(hex: "0078D4")
        }
    }

    private func connectProvider(_ provider: CalendarProvider) {
        Task {
            switch provider {
            case .apple:
                _ = await accountManager.connectAppleCalendar()

            case .google:
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootVC = windowScene.windows.first?.rootViewController else { return }
                _ = await accountManager.connectGoogleCalendar(presenting: rootVC)

            case .microsoft:
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                _ = await accountManager.connectMicrosoftCalendar(anchor: window)
            }
        }
    }

    private func calendarFeatureCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Color.fdAccent)
                    .clipShape(Circle())

                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)

                Spacer()
            }

            Text(description)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .padding(.leading, 48)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.fdAccentLight.opacity(0.5), Color.fdBackground]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorder, lineWidth: 1)
        )
    }
}
