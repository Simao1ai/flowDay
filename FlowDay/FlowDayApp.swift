// FlowDayApp.swift — DIAGNOSTIC RETEST
// Exact copy of the build that worked (build 23), with cleaned-up services

import SwiftUI
import SwiftData

@main
struct FlowDayApp: App {

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
                    } else {
                        VStack(spacing: 20) {
                            Text("FlowDay")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Login screen reached!")
                                .font(.title2)
                            Text("Build 31 — same as working build 23 + cleaned services")
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
                Text("Database Error")
                    .foregroundColor(.red)
            }
        }
    }
}

// Stubs for compilation
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

struct AuthenticatedRootView: View {
    let appState: AppState
    let authManager: AuthManager
    var body: some View { EmptyView() }
}
