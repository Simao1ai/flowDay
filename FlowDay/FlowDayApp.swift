// FlowDayApp.swift
// FlowDay — AI Daily Planner & Tasks

import SwiftUI
import SwiftData
import UserNotifications

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
                                // Delayed restore so it runs after LoginView is rendered
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    authManager.restoreSession()
                                }
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
    @State private var emailAccountService = EmailAccountService()
    @State private var proAccessManager = ProAccessManager.shared
    @State private var showWhatsNew = false

    var body: some View {
        RootView()
            .environment(appState)
            .environment(authManager)
            .environment(calendarAccountManager)
            .environment(emailAccountService)
            .environment(proAccessManager)
            .onAppear {
                scheduleWeeklyReportNotification()
                // Auto-show What's New when app version changes
                if WhatsNewView.hasUnseenUpdate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showWhatsNew = true
                    }
                }
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
            }
    }

    private func scheduleWeeklyReportNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your Weekly Report is Ready"
            content.body = "See how productive you were this week and get AI tips for next week."
            content.sound = .default

            var components = DateComponents()
            components.weekday = 1  // Sunday
            components.hour = 20    // 8 PM
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "fd.weeklyReport",
                content: content,
                trigger: trigger
            )
            center.add(request)
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
