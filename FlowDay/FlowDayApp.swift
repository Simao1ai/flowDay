// FlowDayApp.swift — DIAGNOSTIC: minimal launch path
// All Supabase, GoogleSignIn, and Auth removed from launch path.
// Purpose: isolate whether SIGABRT originates in those frameworks or in SwiftData.

import SwiftUI
import SwiftData

@main
struct FlowDayApp: App {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var sharedModelContainer: ModelContainer? = {
        print("[DIAG] Creating ModelContainer...")
        let schema = Schema([
            FDTask.self,
            FDSubtask.self,
            FDProject.self,
            FDHabit.self,
            FDHabitLog.self,
            FDEnergyLog.self,
            FDFocusSession.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("[DIAG] ModelContainer OK")
            return container
        } catch {
            print("[DIAG] ModelContainer FAILED: \(error)")
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
                        Text("Login screen reached!")
                            .font(.largeTitle)
                            .padding()
                    }
                }
                .tint(Color.fdAccent)
                .onAppear {
                    print("[DIAG] onAppear — hasSeenOnboarding=\(hasSeenOnboarding)")
                }
                .modelContainer(container)
            } else {
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

// MARK: - AuthenticatedRootView (stub — keeps other files compiling)

struct AuthenticatedRootView: View {
    let appState: AppState
    let authManager: AuthManager

    var body: some View {
        Text("AuthenticatedRootView stub")
    }
}
