// FlowDayApp.swift
// FlowDay — AI Daily Planner & Tasks

import SwiftUI
import SwiftData

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

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
            } else {
                Text("Database Error")
                    .foregroundColor(.red)
            }
        }
    }

}

// MARK: - Authenticated Root View (not used until RootView is fixed)
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
