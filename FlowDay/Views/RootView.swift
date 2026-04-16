// RootView.swift
// FlowDay
//
// The main navigation shell. Uses a tab bar on iPhone
// and a sidebar on iPad (adaptive layout).

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var taskService: TaskService?
    @State private var calendarService = CalendarService()
    @State private var showEnergyCheckIn = true

    var body: some View {
        @Bindable var state = appState

        ZStack {
            TabView(selection: $state.selectedTab) {
                TodayView(taskService: taskService, calendarService: calendarService)
                    .tabItem {
                        Label("Today", systemImage: "sun.max")
                    }
                    .tag(AppState.Tab.today)

                UpcomingPlaceholderView()
                    .tabItem {
                        Label("Upcoming", systemImage: "calendar")
                    }
                    .tag(AppState.Tab.upcoming)

                InboxPlaceholderView()
                    .tabItem {
                        Label("Inbox", systemImage: "tray")
                    }
                    .tag(AppState.Tab.inbox)

                HabitsPlaceholderView()
                    .tabItem {
                        Label("Habits", systemImage: "flame")
                    }
                    .tag(AppState.Tab.habits)
            }
            .tint(Color.fdAccent)

            // Energy check-in modal
            if showEnergyCheckIn && appState.todayEnergy == nil {
                EnergyCheckInView(
                    onSelect: { level in
                        appState.todayEnergy = level
                        withAnimation(.easeOut(duration: 0.3)) {
                            showEnergyCheckIn = false
                        }
                        // Log the energy level
                        let log = FDEnergyLog(level: level)
                        modelContext.insert(log)
                        try? modelContext.save()
                    },
                    onSkip: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showEnergyCheckIn = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            taskService = TaskService(modelContext: modelContext)
        }
    }
}

// MARK: - Placeholder Views (to be built out)

struct UpcomingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fdTextMuted)
                Text("Upcoming")
                    .font(.fdTitle2)
                Text("Your upcoming tasks and deadlines will appear here.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Upcoming")
        }
    }
}

struct InboxPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fdTextMuted)
                Text("Inbox")
                    .font(.fdTitle2)
                Text("Unscheduled tasks land here. Triage them into projects.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Inbox")
        }
    }
}

struct HabitsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "flame")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.fdTextMuted)
                Text("Habits")
                    .font(.fdTitle2)
                Text("Track your daily habits with streaks and analytics.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Habits")
        }
    }
}
