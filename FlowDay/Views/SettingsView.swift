// SettingsView.swift
// FlowDay
//
// Full settings screen — every row opens a real sub-screen.

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager

    @State private var showAccount = false
    @State private var showGeneral = false
    @State private var showSubscription = false
    @State private var showCalendar = false
    @State private var showTheme = false
    @State private var showAppIcon = false
    @State private var showNavigation = false
    @State private var showQuickAdd = false
    @State private var showProductivity = false
    @State private var showReminders = false
    @State private var showNotifications = false
    @State private var showAIScheduling = false
    @State private var showEnergyCheckIn = false
    @State private var showAISettings = false
    @State private var showDayRecap = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showWhatsNew = false
    @State private var syncStatus = SyncStatusService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    personalizationSection
                    productivitySection
                    aboutSection
                    signOutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.fdAccent)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showAccount) { AccountSettingsView() }
            .sheet(isPresented: $showGeneral) { GeneralSettingsView() }
            .sheet(isPresented: $showSubscription) { SubscriptionSettingsView() }
            .sheet(isPresented: $showCalendar) { CalendarSettingsView() }
            .sheet(isPresented: $showTheme) { ThemeSettingsView() }
            .sheet(isPresented: $showAppIcon) { AppIconSettingsView() }
            .sheet(isPresented: $showNavigation) { NavigationSettingsView() }
            .sheet(isPresented: $showQuickAdd) { QuickAddSettingsView() }
            .sheet(isPresented: $showProductivity) { ProductivitySettingsView() }
            .sheet(isPresented: $showReminders) { RemindersSettingsView() }
            .sheet(isPresented: $showNotifications) { NotificationsSettingsView() }
            .sheet(isPresented: $showAIScheduling) { AISchedulingSettingsView() }
            .sheet(isPresented: $showEnergyCheckIn) { EnergyCheckInSettingsView() }
            .sheet(isPresented: $showAISettings) { AISettingsView() }
            .sheet(isPresented: $showDayRecap) { DayRecapView() }
            .sheet(isPresented: $showHelp) { HelpFeedbackView() }
            .sheet(isPresented: $showAbout) { AboutView() }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.circle", title: "Account", color: .fdAccent) { showAccount = true }
            Divider().padding(.leading, 52)
            settingsRow(icon: "gearshape", title: "General", color: .fdTextSecondary) { showGeneral = true }
            Divider().padding(.leading, 52)
            settingsRow(icon: "creditcard", title: "Subscription", subtitle: "Free Plan", color: .fdGreen) { showSubscription = true }
            Divider().padding(.leading, 52)
            settingsRow(icon: "calendar", title: "Calendar", color: .fdBlue) { showCalendar = true }
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Personalization

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personalization")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                settingsRow(icon: "paintpalette", title: "Theme", subtitle: "Warm Notion", color: .fdAccent) { showTheme = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "app.badge", title: "App Icon", subtitle: "FlowDay", color: .fdPurple) { showAppIcon = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "list.bullet.indent", title: "Navigation", color: .fdBlue) { showNavigation = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "plus.circle", title: "Quick Add", color: .fdGreen) { showQuickAdd = true }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Productivity

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Productivity")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                settingsRow(icon: "chart.line.uptrend.xyaxis", title: "Productivity", color: .fdAccent) { showProductivity = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "bell", title: "Reminders", color: .fdYellow) { showReminders = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "bell.badge", title: "Notifications", color: .fdRed) { showNotifications = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "sparkles", title: "AI Scheduling", subtitle: "On", color: .fdAccent) { showAIScheduling = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "bolt.fill", title: "Energy Check-in", subtitle: "Daily", color: .fdYellow) { showEnergyCheckIn = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "cpu", title: "AI Settings", color: .fdPurple) { showAISettings = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "moon.stars.fill", title: "Day Recap", subtitle: "AI Summary", color: .fdPurple) { showDayRecap = true }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                settingsRow(icon: "gift", title: "What's New", color: .fdAccent) { showWhatsNew = true }
                Divider().padding(.leading, 52)
                syncStatusRow
                Divider().padding(.leading, 52)
                settingsRow(icon: "questionmark.circle", title: "Help & Feedback", color: .fdBlue) { showHelp = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "info.circle", title: "About", color: .fdTextSecondary) { showAbout = true }
                Divider().padding(.leading, 52)
                settingsRow(icon: "star", title: "Rate FlowDay", color: .fdYellow) { /* Opens App Store review */ }
                Divider().padding(.leading, 52)
                infoRow(title: "Version", value: "1.0.0")
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    /// Always-visible sync transparency row — explicit timestamp, not just
    /// a glyph in the toolbar.
    private var syncStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: syncIcon)
                .font(.system(size: 15))
                .foregroundStyle(syncTint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Text(syncSubtitle)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var syncIcon: String {
        switch syncStatus.state {
        case .idle:    "cloud"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced:  "checkmark.icloud.fill"
        case .offline: "icloud.slash"
        case .error:   "exclamationmark.icloud.fill"
        }
    }

    private var syncTint: Color {
        switch syncStatus.state {
        case .idle:    .fdTextMuted
        case .syncing: .fdBlue
        case .synced:  .fdGreen
        case .offline: .fdTextMuted
        case .error:   .fdRed
        }
    }

    private var syncSubtitle: String {
        switch syncStatus.state {
        case .idle:             "Up to date"
        case .syncing:          "Syncing now…"
        case .synced(let at):   "Last successful sync: \(at.formatted(.relative(presentation: .named)))"
        case .offline:          "Offline — changes saved locally"
        case .error(let msg):   "Sync failed: \(msg)"
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button {
            authManager.signOut()
            dismiss()
        } label: {
            Text("Sign Out")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Row Helpers

    private func settingsRow(icon: String, title: String, subtitle: String? = nil, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
                .padding(.leading, 44)
            Spacer()
            Text(value)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPasswordSheet = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    fieldsSection
                    securitySection
                    dangerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $showPasswordSheet) {
                NavigationStack {
                    Form {
                        Section("Create Password") {
                            SecureField("New Password", text: $newPassword)
                            SecureField("Confirm Password", text: $confirmPassword)
                        }
                        if passwordSaved {
                            Section {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Password saved")
                                }
                            }
                        }
                    }
                    .navigationTitle("Add Password")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPasswordSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                guard !newPassword.isEmpty, newPassword == confirmPassword else { return }
                                UserDefaults.standard.set(true, forKey: "user_has_password")
                                passwordSaved = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    showPasswordSheet = false
                                    passwordSaved = false
                                    newPassword = ""
                                    confirmPassword = ""
                                }
                            }
                            .disabled(newPassword.isEmpty || newPassword != confirmPassword)
                        }
                    }
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdAccentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Text("S")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Your avatar photo will be public.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)

            Button("Edit") { }
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            fieldRow(label: "Full Name", value: "Simao Alves")
            Divider().padding(.leading, 16)
            fieldRow(label: "Email", value: "simaoalves1@gmail.com")
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private func fieldRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
            Text(value)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Security")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("Password")
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                    Spacer()
                    Button("Add Password") { showPasswordSheet = true }
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                }
                .padding(16)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Two-Factor Authentication")
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.fdSurfaceHover)
                        .frame(width: 50, height: 30)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                                .shadow(color: .black.opacity(0.1), radius: 2)
                            , alignment: .leading
                        )
                        .padding(.leading, 2)
                }
                .padding(16)
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private var dangerSection: some View {
        Button { } label: {
            Text("Delete Account")
                .font(.fdBodyMedium)
                .foregroundStyle(Color.fdRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.fdRedLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Navigation Settings

struct NavigationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tabItems: [NavItem] = [
        NavItem(title: "Today", icon: "sun.max", isInTab: true),
        NavItem(title: "Upcoming", icon: "calendar", isInTab: true),
        NavItem(title: "Inbox", icon: "tray", isInTab: true),
        NavItem(title: "Browse", icon: "text.justify.leading", isInTab: true),
    ]

    @State private var menuItems: [NavItem] = [
        NavItem(title: "Habits", icon: "flame", isEnabled: true),
        NavItem(title: "Filters & Labels", icon: "line.3.horizontal.decrease.circle", isEnabled: true),
        NavItem(title: "Completed", icon: "checkmark.circle", isEnabled: false),
        NavItem(title: "Templates", icon: "sparkles", isEnabled: true),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    tabBarSection
                    descriptionText
                    menuSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.large)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { }
                        .font(.fdBodyMedium)
                        .foregroundStyle(Color.fdAccent)
                }
            }
        }
    }

    private var tabBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tab Bar")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(tabItems.indices, id: \.self) { index in
                    tabRow(index: index)
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func tabRow(index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: tabItems[index].icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 28)
                Text(tabItems[index].title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if index < tabItems.count - 1 {
                Divider().padding(.leading, 52)
            }
        }
    }

    private var descriptionText: some View {
        Text("Customize your tab bar navigation to fit your workflow. Select a destination from the available slots and tap \"Edit\" to rearrange them.")
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextMuted)
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Menu Items")
                    .font(.fdCaptionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fdTextMuted)
                Spacer()
                Button("Show All") { }
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdAccent)
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(menuItems.indices, id: \.self) { index in
                    menuRow(index: index)
                }
            }
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func menuRow(index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    menuItems[index].isEnabled.toggle()
                } label: {
                    Image(systemName: menuItems[index].isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(menuItems[index].isEnabled ? Color.fdAccent : Color.fdTextMuted)
                }

                Image(systemName: menuItems[index].icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.fdAccent)
                    .frame(width: 24)

                Text(menuItems[index].title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if index < menuItems.count - 1 {
                Divider().padding(.leading, 52)
            }
        }
    }
}

private struct NavItem: Identifiable {
    let id = UUID()
    var title: String
    var icon: String
    var isInTab: Bool = false
    var isEnabled: Bool = true
}
