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
            FDTaskAttachment.self,
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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
            } else {
                Text("Database Error")
                    .foregroundColor(.red)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "flowday" else { return }
        if url.host == "task",
           let idString = url.pathComponents.dropFirst().first,
           let id = UUID(uuidString: idString) {
            appState.deepLinkedTaskID = id
        } else if url.host == "recap" {
            appState.showEndOfDayRecap = true
        }
    }

}

// MARK: - Authenticated Root View
struct AuthenticatedRootView: View {
    let appState: AppState
    let authManager: AuthManager
    @State private var calendarAccountManager = CalendarAccountManager()

    @Query private var allTasksRaw: [FDTask]

    private var deepLinkedTask: FDTask? {
        guard let id = appState.deepLinkedTaskID else { return nil }
        return allTasksRaw.first { $0.id == id }
    }

    var body: some View {
        @Bindable var state = appState
        RootView()
            .environment(appState)
            .environment(authManager)
            .environment(calendarAccountManager)
            .sheet(isPresented: Binding(
                get: { appState.deepLinkedTaskID != nil && deepLinkedTask != nil },
                set: { if !$0 { appState.deepLinkedTaskID = nil } }
            )) {
                if let task = deepLinkedTask {
                    TaskDetailSheet(task: task, taskService: nil)
                }
            }
            .sheet(isPresented: $state.showEndOfDayRecap) {
                EndOfDayRecapView()
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
    var deepLinkedTaskID: UUID? = nil
    var showEndOfDayRecap: Bool = false

    enum Tab: String, CaseIterable {
        case today = "Today"
        case upcoming = "Upcoming"
        case flowAI = "Flow AI"
        case inbox = "Inbox"
        case habits = "Habits"
        case browse = "Browse"
    }
}
