// FlowDayApp.swift
// FlowDay — AI Daily Planner & Tasks
// Updated: Wires onboarding, real auth, dark mode, Keychain migration, and CloudKit sync.
//
// INTEGRATION NOTES:
// 1. Replace the original FlowDayApp.swift with this file
// 2. Remove .preferredColorScheme(.light) — dark mode is now supported
// 3. Add GoogleSignIn SPM package: https://github.com/google/GoogleSignIn-iOS
// 4. Enable "Sign in with Apple" capability in Xcode
// 5. Enable CloudKit in Xcode → Signing & Capabilities → iCloud → check CloudKit
// 6. Add to Info.plist: NSCalendarsUsageDescription, NSSpeechRecognitionUsageDescription, NSMicrophoneUsageDescription

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct FlowDayApp: App {

    @State private var appState = AppState()
    @State private var authManager = AuthManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var sharedModelContainer: ModelContainer? = {
        let schema = Schema([
            FDTask.self,
            FDSubtask.self,
            FDProject.self,
            FDHabit.self,
            FDHabitLog.self,
            FDEnergyLog.self,
            FDFocusSession.self,
        ])

        // CloudKit-enabled configuration for cross-device sync
        // To use CloudKit, ensure "iCloud" capability is enabled in Xcode
        // with a CloudKit container like "iCloud.com.flowday.app"
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // Enables iCloud sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("ModelContainer FAILED: \(error)")
            // Fallback: try without CloudKit if iCloud isn't set up yet
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try? ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                Group {
                    if !hasSeenOnboarding {
                        // Step 1: Show onboarding on first launch
                        OnboardingView()
                    } else if !authManager.isAuthenticated {
                        // Step 2: Show login after onboarding
                        LoginView()
                            .environment(authManager)
                    } else {
                        // Step 3: Main app
                        RootView()
                            .environment(appState)
                            .environment(authManager)
                            .modelContainer(container)
                    }
                }
                .tint(Color.fdAccent)
                // NO .preferredColorScheme(.light) — dark mode is now supported!
                .onAppear {
                    // Restore auth session from Keychain on launch
                    authManager.restoreSession()

                    // Migrate LLM API keys from UserDefaults to Keychain (one-time)
                    LLMService.shared.migrateKeysFromUserDefaults()
                }
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
            } else {
                // Database error fallback
                databaseErrorView
            }
        }
    }

    // MARK: - Database Error Fallback

    private var databaseErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.fdRed)
            Text("Database Error")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)
            Text("SwiftData could not initialize.\nTry deleting and reinstalling the app.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Global App State

@Observable
final class AppState {
    var selectedTab: Tab = .today
    var showEnergyCheckIn: Bool = true
    var todayEnergy: EnergyLevel? = nil
    var showQuickAdd: Bool = false
    var selectedDate: Date = .now
    var sidebarVisible: Bool = true
    var hasSeededData: Bool = false

    enum Tab: String, CaseIterable {
        case today = "Today"
        case upcoming = "Upcoming"
        case flowAI = "Flow AI"
        case inbox = "Inbox"
        case habits = "Habits"
        case browse = "Browse"
    }
}
