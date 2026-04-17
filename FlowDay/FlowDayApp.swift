// FlowDayApp.swift — DIAGNOSTIC BUILD
// Minimal version to isolate SIGABRT crash

import SwiftUI
import SwiftData

@main
struct FlowDayApp: App {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

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
                    } else {
                        // DIAGNOSTIC: Simple placeholder instead of full LoginView
                        VStack(spacing: 20) {
                            Text("FlowDay")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Login screen reached!")
                                .font(.title2)
                            Text("If you see this, the crash is NOT in SwiftData or the basic app structure.")
                                .multilineTextAlignment(.center)
                                .padding()
                            Button("Reset Onboarding") {
                                hasSeenOnboarding = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .tint(Color.fdAccent)
            } else {
                Text("Database Error — ModelContainer failed to initialize")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Global App State (kept for compilation)

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

// Keep AuthenticatedRootView stub for compilation
struct AuthenticatedRootView: View {
    let appState: AppState
    let authManager: AuthManager
    var body: some View { EmptyView() }
}
