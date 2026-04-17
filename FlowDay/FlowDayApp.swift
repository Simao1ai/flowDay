// FlowDayApp.swift
// FlowDay — AI Daily Planner & Tasks
//
// INTEGRATION NOTES:
// 1. Add GoogleSignIn SPM package: https://github.com/google/GoogleSignIn-iOS
// 2. Add Supabase Swift SDK via SPM: https://github.com/supabase/supabase-swift
// 3. Copy FlowDay/Config.example.swift → FlowDay/Config.swift and fill in credentials
// 4. Enable "Sign in with Apple" capability in Xcode
// 5. Enable CloudKit in Xcode → Signing & Capabilities → iCloud → check CloudKit
// 6. Add to Info.plist: NSCalendarsUsageDescription, NSSpeechRecognitionUsageDescription,
//    NSMicrophoneUsageDescription
// 7. See SETUP.md for full Supabase + Edge Function setup

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct FlowDayApp: App {

    @State private var appState = AppState()
    @State private var authManager = AuthManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        print("[FlowDay] App init starting")
        // Configure Google Sign-In at launch so the client ID is available before
        // any view appears, preventing a nil-configuration SIGABRT on first tap.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "777744388308-7k3sm0fcdkg6qg7tlqjc463oj5qam6b3.apps.googleusercontent.com"
        )
        print("[FlowDay] GIDSignIn configured")
    }

    var sharedModelContainer: ModelContainer? = {
        print("[FlowDay] Creating ModelContainer...")
        let schema = Schema([
            FDTask.self,
            FDSubtask.self,
            FDProject.self,
            FDHabit.self,
            FDHabitLog.self,
            FDEnergyLog.self,
            FDFocusSession.self,
        ])

        // CloudKit disabled: Supabase handles sync. CloudKit also requires every
        // attribute to be optional with a default value — a constraint we don't
        // want to impose on the model layer just for iCloud sync.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[FlowDay] ModelContainer created successfully")
            return container
        } catch {
            print("ModelContainer FAILED: \(error)")
            return nil
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
                        // Step 3: Main app — CalendarAccountManager is initialized here,
                        // after auth, so EventKit is ready when loadAccounts() runs.
                        AuthenticatedRootView(appState: appState, authManager: authManager)
                            .modelContainer(container)
                    }
                }
                .tint(Color.fdAccent)
                // NO .preferredColorScheme(.light) — dark mode is now supported!
                .onAppear {
                    print("[FlowDay] onAppear fired, hasSeenOnboarding=\(hasSeenOnboarding)")
                    // Only restore session after onboarding — no need to touch Supabase during onboarding
                    guard hasSeenOnboarding else { return }

                    authManager.restoreSession()

                    if let container = sharedModelContainer {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            guard authManager.isAuthenticated else { return }
                            let context = container.mainContext
                            let tasks = (try? context.fetch(FetchDescriptor<FDTask>())) ?? []
                            let projects = (try? context.fetch(FetchDescriptor<FDProject>())) ?? []
                            await SupabaseService.shared.syncAll(tasks: tasks, projects: projects)
                        }
                    }
                }
                .onChange(of: hasSeenOnboarding) { oldValue, newValue in
                    if newValue {
                        authManager.restoreSession()
                    }
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

// MARK: - Authenticated Root View

/// Owns CalendarAccountManager so it is only initialized after the user has
/// authenticated — not during onboarding or login where EventKit isn't ready.
struct AuthenticatedRootView: View {
    let appState: AppState
    let authManager: AuthManager
    @State private var calendarAccountManager = CalendarAccountManager()

    var body: some View {
        RootView()
            .environment(appState)
            .environment(authManager)
            .environment(calendarAccountManager)
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
