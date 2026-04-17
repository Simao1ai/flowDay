// FlowDayApp.swift
// FlowDay — AI Daily Planner & Tasks

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

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[FlowDay] ModelContainer created OK")
            return container
        } catch {
            print("[FlowDay] ModelContainer FAILED: \(error)")
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                Group {
                    if !hasSeenOnboarding {
                        OnboardingView()
                    } else if !authManager.isAuthenticated {
                        LoginView()
                            .environment(authManager)
                            .onAppear {
                                authManager.restoreSession()
                            }
                    } else {
                        AuthenticatedRootView(appState: appState, authManager: authManager)
                            .modelContainer(container)
                    }
                }
                .tint(Color.fdAccent)
                // Supabase sync disabled — SDK crashes on iOS 26.x
                // TODO: Replace with direct REST API calls
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
            } else {
                Text("Database Error")
                    .foregroundColor(.red)
            }
        }
    }

    private var databaseErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.fdRed)
            Text("Database Error")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)
        }
    }
}

// MARK: - Authenticated Root View
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
