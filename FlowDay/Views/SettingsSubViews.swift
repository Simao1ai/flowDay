// SettingsSubViews.swift
// FlowDay
//
// All settings sub-screens — each row in Settings opens one of these.

import SwiftUI
import StoreKit

// MARK: - General Settings

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
                    // Home
                    settingsGroup {
                        pickerRow(title: "Home View", selection: $homeView, options: ["Today", "Upcoming", "Inbox"])
                        Divider().padding(.leading, 16)
                        toggleRow(title: "Sync Home View", isOn: $syncHomeView, subtitle: "When turned on, your Home view will be the same on all platforms.")
                    }

                    // Smart Date Recognition
                    settingsGroup {
                        toggleRow(title: "Smart Date Recognition", isOn: $smartDateRecognition, subtitle: "Detect dates in tasks automatically")
                    }

                    // Sub-Tasks
                    settingsGroup {
                        toggleRow(title: "Reset Sub-Tasks", isOn: $resetSubTasks, subtitle: "Reset sub-tasks when you complete a recurring task.")
                    }

                    // Date & Time
                    sectionHeader("Date & Time")
                    settingsGroup {
                        pickerRow(title: "Timezone", selection: $timezone, options: ["Auto", "UTC", "EST", "PST", "CST", "GMT"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Start Week On", selection: $startWeekOn, options: ["Sunday", "Monday", "Saturday"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Interpret \"Next Week\" As", selection: $interpretNextWeek, options: ["Monday", "Tuesday"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Interpret \"Weekend\" As", selection: $interpretWeekend, options: ["Saturday", "Friday"])
                    }

                    // App Settings
                    sectionHeader("App Settings")
                    settingsGroup {
                        pickerRow(title: "Open Web Links In", selection: $openWebLinksIn, options: ["FlowDay", "Safari", "Chrome"])
                    }

                    // Sound
                    sectionHeader("Sound")
                    settingsGroup {
                        navRow(title: "Task Complete Tone", subtitle: nil, value: "Default")
                    }

                    // Swipe Actions
                    sectionHeader("Swipe Actions")
                    settingsGroup {
                        pickerRow(title: "Right Swipe", selection: $rightSwipe, options: ["Reschedule", "Complete", "Delete"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Left Swipe", selection: $leftSwipe, options: ["Complete", "Delete", "Schedule"])
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
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Subscription Settings

struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: String = "yearly"
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorText = ""

    private var subscriptionManager: SubscriptionManager { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                    .padding(.bottom, 8)

                    // Feature illustration
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 100, height: 100)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.fdAccent, Color.fdAccentSoft]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())

                    // Headline
                    VStack(spacing: 8) {
                        Text("Try Pro for Free")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text("Supercharge your productivity")
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdTextSecondary)
                        Text("Get the full FlowDay experience")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .multilineTextAlignment(.center)

                    // Dot indicator
                    HStack(spacing: 6) {
                        Circle().fill(Color.fdAccent).frame(width: 6, height: 6)
                        Circle().fill(Color.fdBorder).frame(width: 6, height: 6)
                        Circle().fill(Color.fdBorder).frame(width: 6, height: 6)
                    }

                    // Pricing cards
                    VStack(spacing: 12) {
                        // Yearly
                        Button { selectedPlan = "yearly" } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pay Yearly")
                                            .font(.fdBodySemibold)
                                            .foregroundStyle(Color.fdText)
                                        Text(subscriptionManager.yearlyProduct?.displayPrice ?? "$49.99")
                                            .font(.fdTitle3)
                                            .foregroundStyle(Color.fdText)
                                        Text("$4.17/mo")
                                            .font(.fdCaption)
                                            .foregroundStyle(Color.fdTextSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Save $23.89")
                                            .font(.fdMicroBold)
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.fdAccent)
                                            .clipShape(Capsule())
                                        Image(systemName: selectedPlan == "yearly" ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.fdAccent)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.fdSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPlan == "yearly" ? Color.fdAccent : Color.fdBorder, lineWidth: selectedPlan == "yearly" ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        // Monthly
                        Button { selectedPlan = "monthly" } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pay Monthly")
                                            .font(.fdBodySemibold)
                                            .foregroundStyle(Color.fdText)
                                        Text(subscriptionManager.monthlyProduct?.displayPrice ?? "$5.99")
                                            .font(.fdTitle3)
                                            .foregroundStyle(Color.fdText)
                                        Text("$5.99/mo")
                                            .font(.fdCaption)
                                            .foregroundStyle(Color.fdTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedPlan == "monthly" ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.fdAccent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.fdSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPlan == "monthly" ? Color.fdAccent : Color.fdBorder, lineWidth: selectedPlan == "monthly" ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Account info
                    VStack(spacing: 4) {
                        Text("Account didn't upgrade?")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                        Button("Refresh Subscription") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdAccent)
                    }
                    .frame(maxWidth: .infinity)

                    Text("Due today: $0.00")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)

                    // CTA Button
                    Button {
                        Task {
                            isPurchasing = true
                            defer { isPurchasing = false }

                            let product: Product?
                            if selectedPlan == "yearly" {
                                product = subscriptionManager.yearlyProduct
                            } else {
                                product = subscriptionManager.monthlyProduct
                            }

                            guard let product else {
                                errorText = "Subscriptions are not yet available. Products will be available soon — thank you for your patience!"
                                showError = true
                                return
                            }

                            do {
                                _ = try await subscriptionManager.purchase(product)
                            } catch {
                                errorText = error.localizedDescription
                                showError = true
                            }
                        }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Continue to Free Trial")
                                .font(.fdBodySemibold)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.fdAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isPurchasing)

                    // Footer
                    Text("All FlowDay features. Free 7-day trial. Cancel anytime.")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationBarHidden(true)
            .alert("Subscription", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorText)
            }
        }
    }
}

// MARK: - Theme Settings

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme = "FlowDay"
    @State private var syncTheme = true
    @State private var autoDarkMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Toggles
                    settingsGroup {
                        toggleRow(title: "Sync Theme", isOn: $syncTheme, subtitle: "Sync your theme across devices")
                        Divider().padding(.leading, 16)
                        toggleRow(title: "Auto Dark Mode", isOn: $autoDarkMode, subtitle: "Sync with your device's Dark Mode")
                    }

                    // Free themes
                    VStack(spacing: 12) {
                        themeListItem(name: "FlowDay", accentColor: Color.fdAccent, isSelected: selectedTheme == "FlowDay")
                            .onTapGesture { selectedTheme = "FlowDay" }
                        themeListItem(name: "Midnight", accentColor: Color(hex: "2A2A3E"), isSelected: selectedTheme == "Midnight")
                            .onTapGesture { selectedTheme = "Midnight" }
                        themeListItem(name: "Moonstone", accentColor: Color(hex: "9CA3AF"), isSelected: selectedTheme == "Moonstone")
                            .onTapGesture { selectedTheme = "Moonstone" }
                        themeListItem(name: "Tangerine", accentColor: Color(hex: "FB923C"), isSelected: selectedTheme == "Tangerine")
                            .onTapGesture { selectedTheme = "Tangerine" }
                    }

                    // Unlock more themes
                    proUpsellCard(icon: "star.fill", title: "Unlock more themes", message: "Get access to exclusive themes designed to inspire your productivity.")

                    // Pro themes section
                    sectionHeader("PRO THEMES")

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }

    private func themeListItem(name: String, accentColor: Color, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Theme preview
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.fdAccentLight : Color.fdSurfaceHover)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 6)
                    .fill(accentColor.opacity(0.5))
                    .frame(height: 8)
            }
            .frame(width: 50)

            // Name
            Text(name)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            // Checkmark
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
            // Theme preview
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fdSurfaceHover)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.fdBorder)
                    .frame(height: 8)
            }
            .frame(width: 50)

            // Name
            Text(name)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            // Lock icon
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

// MARK: - Calendar Settings

struct CalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarAccountManager.self) private var accountManager
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: CalendarProvider? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connected accounts
                    if !accountManager.connectedAccounts.isEmpty {
                        connectedSection
                    }

                    // Available providers to connect
                    connectSection

                    // Error message
                    if let error = accountManager.connectionError {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // Description
                    Text("Connect your calendar accounts to see all your events in FlowDay. Your schedule helps the AI planner find the best time slots for your tasks.")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .multilineTextAlignment(.center)

                    // Features
                    sectionHeader("WHAT YOU CAN DO")

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
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
    }

    // MARK: - Connected Accounts Section

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            settingsGroup {
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

    // MARK: - Connect Section

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Calendar Account")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            settingsGroup {
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

    // MARK: - Provider Icon

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

    // MARK: - Connect Actions

    private func connectProvider(_ provider: CalendarProvider) {
        Task {
            switch provider {
            case .apple:
                _ = await accountManager.connectAppleCalendar()

            case .google:
                // Get the root view controller for presenting Google Sign-In
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootVC = windowScene.windows.first?.rootViewController else { return }
                _ = await accountManager.connectGoogleCalendar(presenting: rootVC)

            case .microsoft:
                // Get the window for presenting ASWebAuthenticationSession
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                _ = await accountManager.connectMicrosoftCalendar(anchor: window)
            }
        }
    }

    // MARK: - Feature Cards

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

// MARK: - App Icon Settings

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
                    // Current icon preview
                    if let current = freeIcons.first(where: { $0.name == selectedIcon }) {
                        currentIconPreview(current)
                    }

                    // Free icons grid
                    sectionHeader("FREE ICONS")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(freeIcons) { icon in
                            iconGridItem(icon: icon, isSelected: selectedIcon == icon.name)
                                .onTapGesture { selectedIcon = icon.name }
                        }
                    }

                    // Pro upsell
                    proUpsellCard(icon: "star.fill", title: "Unlock all icons", message: "Get exclusive icon designs with FlowDay Pro.")

                    // Pro icons
                    sectionHeader("PRO ICONS")

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
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
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

// MARK: - Quick Add Settings

struct QuickAddSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showActionLabels = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Show action labels toggle
                    settingsGroup {
                        toggleRow(title: "Show action labels", isOn: $showActionLabels, subtitle: nil)
                    }

                    // Example preview
                    VStack(spacing: 8) {
                        Text("Example")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            actionChip("Date")
                            actionChip("Priority")
                            actionChip("Project")
                            actionChip("Duration")
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Included task actions
                    sectionHeader("Included Task Actions")

                    VStack(spacing: 0) {
                        taskActionRow(icon: "calendar", title: "Date", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "flag.fill", title: "Priority", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "folder.fill", title: "Project", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "clock.fill", title: "Duration", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "bell.fill", title: "Reminders", isIncluded: true)
                    }
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // More task actions
                    sectionHeader("More Task Actions")

                    VStack(spacing: 0) {
                        taskActionRow(icon: "tag.fill", title: "Labels", isIncluded: false)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "calendar.badge.plus", title: "Start Date", isIncluded: false)
                        Divider().padding(.leading, 52)
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.fdGreen)
                                .frame(width: 28)
                            Text("Cognitive Load")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.fdYellow)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.fdYellowLight)
                                .clipShape(Capsule())
                            Spacer()
                            Image(systemName: "line.3")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }

    private func actionChip(_ label: String) -> some View {
        Text(label)
            .font(.fdCaption)
            .foregroundStyle(Color.fdText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.fdAccentLight)
            .clipShape(Capsule())
    }

    private func taskActionRow(icon: String, title: String, isIncluded: Bool) -> some View {
        HStack(spacing: 12) {
            if isIncluded {
                Button {
                    // Remove action
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.fdRed)
                }
            } else {
                Button {
                    // Add action
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.fdGreen)
                }
            }

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextSecondary)
                .frame(width: 20)

            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            Image(systemName: "line.3")
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Productivity Settings

struct ProductivitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackProductivity = true
    @State private var dailyGoal = 5
    @State private var weeklyGoal = 30
    @State private var celebrateGoals = true
    @AppStorage("vacation_mode_enabled") private var vacationMode = false
    @State private var daysOff: Set<Int> = [0, 6] // Sunday and Saturday

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Track Productivity
                    settingsGroup {
                        toggleRow(title: "Track Productivity Score", isOn: $trackProductivity, subtitle: nil)
                    }

                    // Set Goals
                    sectionHeader("Set Goals")

                    settingsGroup {
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

                    // Goal Celebrations
                    settingsGroup {
                        toggleRow(title: "Goal Celebrations", isOn: $celebrateGoals, subtitle: "Celebrate reaching daily and weekly task goals.")
                    }

                    // Days Off
                    sectionHeader("Days Off")

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { day in
                                let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
                                Button {
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

                    // Vacation Mode
                    settingsGroup {
                        toggleRow(title: "Vacation Mode", isOn: $vacationMode, subtitle: "When turned on, your streaks and Productivity Score will remain intact even if you don't achieve your goals.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Productivity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Reminders Settings

struct RemindersSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Pro upsell
                    proUpsellBanner(
                        icon: "star.fill",
                        title: "Smart reminders included",
                        message: "Free accounts get reminders at task time. FlowDay includes smart reminders that factor in task duration."
                    )

                    // Preferences
                    sectionHeader("Preferences")

                    settingsGroup {
                        navRow(title: "Remind Me Via", subtitle: nil, value: "Push Notifications")
                        Divider().padding(.leading, 16)
                        navRow(title: "When Snoozed...", subtitle: nil, value: "15 minutes")
                        Divider().padding(.leading, 16)
                        navRow(title: "Automatic Reminders", subtitle: "When enabled, a reminder before the task's due time will be added by default.", value: "At time of task")
                    }

                    // Reminders Not Working
                    sectionHeader("REMINDERS NOT WORKING?", color: Color.fdRed)

                    settingsGroup {
                        navRow(title: "Enable Time-Sensitive Notifications", subtitle: "Required for notifications to appear on lock screen.", value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Enable Background App Refresh", subtitle: "Allows FlowDay to process reminders even when closed.", value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Troubleshoot Notifications", subtitle: nil, value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskReminders = true
    @State private var habitReminders = true
    @State private var dailySummary = true
    @State private var summaryTime = "8:00 AM"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsGroup {
                        toggleRow(title: "Task reminders", isOn: $taskReminders, subtitle: "Get notified when it's time for your tasks.")
                        Divider().padding(.leading, 16)
                        toggleRow(title: "Habit reminders", isOn: $habitReminders, subtitle: "Get notified to complete your habits.")
                    }

                    settingsGroup {
                        toggleRow(title: "Daily summary", isOn: $dailySummary, subtitle: "Receive a summary of your day at a set time.")
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Summary time", selection: $summaryTime, options: ["7:00 AM", "8:00 AM", "9:00 AM", "6:00 PM", "9:00 PM"])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - AI Scheduling Settings

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
                    settingsGroup {
                        toggleRow(title: "AI scheduling enabled", isOn: $enabled, subtitle: nil)
                    }

                    settingsGroup {
                        pickerRow(title: "Peak focus start", selection: $peakStart, options: ["7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Peak focus end", selection: $peakEnd, options: ["11:00 AM", "12:00 PM", "1:00 PM", "2:00 PM"])
                    }

                    settingsGroup {
                        toggleRow(title: "Respect calendar events", isOn: $respectCalendar, subtitle: nil)
                        Divider().padding(.leading, 16)
                        toggleRow(title: "Auto-suggest on new tasks", isOn: $autoSuggest, subtitle: nil)
                    }

                    infoCard(
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
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Energy Check-in Settings

struct EnergyCheckInSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = true
    @State private var frequency = "Daily"
    @State private var checkInTime = "Morning"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsGroup {
                        toggleRow(title: "Energy check-in enabled", isOn: $enabled, subtitle: nil)
                    }

                    settingsGroup {
                        pickerRow(title: "Frequency", selection: $frequency, options: ["Daily", "Weekdays only", "Manual"])
                        Divider().padding(.leading, 16)
                        pickerRow(title: "Check-in time", selection: $checkInTime, options: ["Morning", "When I open the app", "Custom time"])
                    }

                    infoCard(
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Help & Feedback

struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Help
                    sectionHeader("Help")

                    settingsGroup {
                        navRow(title: "Getting Started Guide", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Help Center", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Contact Support", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "My Tickets", subtitle: nil, value: nil)
                    }

                    // Feedback
                    sectionHeader("Feedback")

                    settingsGroup {
                        navRow(title: "Rate FlowDay on the App Store", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Share App", subtitle: nil, value: nil)
                    }

                    // Research
                    sectionHeader("Research")

                    settingsGroup {
                        navRow(title: "Book Feedback Session", subtitle: "We'd love to hear your thoughts in a quick 15 minute call about all things FlowDay.", value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Help & Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Version
                    VStack(spacing: 4) {
                        Text("FlowDay 1.0.0")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text("(1)")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    // Changelog
                    settingsGroup {
                        navRow(title: "View changelog", subtitle: nil, value: nil)
                    }

                    Divider()

                    // Links
                    settingsGroup {
                        navRow(title: "Visit flowday.app", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Visit for inspiration", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "We are hiring!", subtitle: nil, value: nil)
                    }

                    // Legal
                    sectionHeader("Legal")

                    settingsGroup {
                        navRow(title: "Acknowledgments", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Privacy Policy", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Security Policy", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        navRow(title: "Terms of Service", subtitle: nil, value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }
}

// MARK: - Shared Helpers

private func backButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.fdText)
            .frame(width: 36, height: 36)
            .background(Color.fdSurfaceHover)
            .clipShape(Circle())
    }
}

private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
    }
    .background(Color.fdSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
}

private func toggleRow(title: String, isOn: Binding<Bool>, subtitle: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color.fdAccent)
                .labelsHidden()
        }
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
}

private func pickerRow(title: String, selection: Binding<String>, options: [String]) -> some View {
    HStack {
        Text(title)
            .font(.fdBody)
            .foregroundStyle(Color.fdText)
        Spacer()
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection.wrappedValue = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
}

private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    HStack {
        Text(title)
            .font(.fdBody)
            .foregroundStyle(Color.fdText)
        Spacer()
        HStack(spacing: 12) {
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fdTextMuted)
            }
            Text("\(value.wrappedValue)")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
                .frame(minWidth: 24)
            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fdAccent)
            }
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
}

private func infoCard(icon: String, title: String, message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 24))
            .foregroundStyle(Color.fdAccent)
        Text(title)
            .font(.fdBodySemibold)
            .foregroundStyle(Color.fdText)
        Text(message)
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color.fdAccentLight)
    .clipShape(RoundedRectangle(cornerRadius: 14))
}

private func navRow(title: String, subtitle: String?, value: String?) -> some View {
    VStack(alignment: .leading, spacing: subtitle != nil ? 4 : 0) {
        HStack {
            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            Spacer()
            if let value = value {
                Text(value)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fdTextMuted)
        }
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
}

private func sectionHeader(_ title: String, color: Color = Color.fdText) -> some View {
    Text(title)
        .font(.fdCaptionBold)
        .foregroundStyle(color)
        .tracking(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
}

private func proUpsellCard(icon: String, title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "B8860B"))
            Text(title)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.fdTextMuted)
        }
        Text(message)
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "FDF8E8"), Color(hex: "FEF3C7")]), startPoint: .topLeading, endPoint: .bottomTrailing))
    .border(Color(hex: "FCD34D"), width: 1)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

private func proUpsellBanner(icon: String, title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.fdAccent)
            Text(title)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
        }
        Text(message)
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.fdAccentLight)
    .border(Color.fdBorder, width: 1)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

// MARK: - AI Settings

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openAIKey: String = LLMService.shared.openAIKey
    @State private var anthropicKey: String = LLMService.shared.anthropicKey
    @State private var geminiKey: String = LLMService.shared.geminiKey
    @State private var primaryProvider: LLMProvider = LLMService.shared.primaryProvider
    @State private var testingConnection = false
    @State private var openAIStatus: Bool?
    @State private var anthropicStatus: Bool?
    @State private var geminiStatus: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Provider selection
                    sectionHeader("Primary Provider")

                    settingsGroup {
                        Menu {
                            Picker("", selection: $primaryProvider) {
                                Text("Google Gemini (Free)").tag(LLMProvider.gemini)
                                Text("OpenAI (GPT-4o)").tag(LLMProvider.openAI)
                                Text("Anthropic (Claude Sonnet)").tag(LLMProvider.anthropic)
                            }
                        } label: {
                            HStack {
                                Text("Select Provider")
                                    .font(.fdBody)
                                    .foregroundStyle(Color.fdText)
                                Spacer()
                                Text(primaryProvider == .gemini ? "Gemini" : primaryProvider == .openAI ? "OpenAI" : "Anthropic")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextMuted)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Google Gemini API Key (Free)
                    sectionHeader("Google Gemini (Free)")

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.fdCaptionBold)
                                .foregroundStyle(Color.fdTextMuted)
                            SecureField("AIza...", text: $geminiKey)
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                                .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Text("Connection Status")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Spacer()
                            if let status = geminiStatus {
                                HStack(spacing: 6) {
                                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                    Text(status ? "Connected" : "Failed")
                                        .font(.fdCaption)
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                }
                            } else {
                                Text("Untested")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // OpenAI API Key
                    sectionHeader("OpenAI")

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.fdCaptionBold)
                                .foregroundStyle(Color.fdTextMuted)
                            SecureField("sk-...", text: $openAIKey)
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                                .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Text("Connection Status")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Spacer()
                            if let status = openAIStatus {
                                HStack(spacing: 6) {
                                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                    Text(status ? "Connected" : "Failed")
                                        .font(.fdCaption)
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                }
                            } else {
                                Text("Untested")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Anthropic API Key
                    sectionHeader("Anthropic")

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.fdCaptionBold)
                                .foregroundStyle(Color.fdTextMuted)
                            SecureField("sk-ant-...", text: $anthropicKey)
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                                .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Text("Connection Status")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Spacer()
                            if let status = anthropicStatus {
                                HStack(spacing: 6) {
                                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                    Text(status ? "Connected" : "Failed")
                                        .font(.fdCaption)
                                        .foregroundStyle(status ? Color.fdGreen : Color.fdRed)
                                }
                            } else {
                                Text("Untested")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Test Connection Button
                    Button(action: testConnections) {
                        if testingConnection {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(Color.fdText)
                                Text("Testing...")
                                    .font(.fdBodySemibold)
                                    .foregroundStyle(Color.fdText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.fdAccentLight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("Test Connection")
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.fdAccentLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .disabled(testingConnection || (openAIKey.isEmpty && anthropicKey.isEmpty && geminiKey.isEmpty))

                    // Info card about API keys
                    infoCard(
                        icon: "info.circle",
                        title: "Where to get API Keys",
                        message: "Gemini (Free): ai.google.dev/aistudio\nOpenAI: platform.openai.com/api-keys\nAnthropic: console.anthropic.com/account/keys"
                    )

                    // Save Button
                    Button(action: saveSettings) {
                        Text("Save Settings")
                            .font(.fdBodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.fdAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { dismiss() } }
            }
        }
    }

    private func testConnections() {
        testingConnection = true

        // Save keys before testing so LLMService uses the latest values
        LLMService.shared.openAIKey = openAIKey
        LLMService.shared.anthropicKey = anthropicKey
        LLMService.shared.geminiKey = geminiKey
        LLMService.shared.primaryProvider = primaryProvider

        Task {
            let results = await LLMService.shared.testConnection()

            await MainActor.run {
                openAIStatus = results.openAI
                anthropicStatus = results.anthropic
                geminiStatus = results.gemini
                testingConnection = false
            }
        }
    }

    private func saveSettings() {
        LLMService.shared.openAIKey = openAIKey
        LLMService.shared.anthropicKey = anthropicKey
        LLMService.shared.geminiKey = geminiKey
        LLMService.shared.primaryProvider = primaryProvider
        dismiss()
    }
}
