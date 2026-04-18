// RootView.swift
// FlowDay
//
// The main navigation shell with full tab bar.

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var taskService: TaskService?
    @State private var calendarService = CalendarService()
    @State private var showEnergyCheckIn = true
    @State private var showSettings = false

    var body: some View {
        @Bindable var state = appState

        ZStack {
            TabView(selection: $state.selectedTab) {
                TodayView(taskService: taskService, calendarService: calendarService)
                    .tabItem {
                        Label("Today", systemImage: "sun.max")
                    }
                    .tag(AppState.Tab.today)

                UpcomingView(taskService: taskService)
                    .tabItem {
                        Label("Upcoming", systemImage: "calendar")
                    }
                    .tag(AppState.Tab.upcoming)

                // Flow AI — center tab
                NavigationStack {
                    AIAssistantView()
                }
                .tabItem {
                    Label("Flow AI", systemImage: "sparkles")
                }
                .tag(AppState.Tab.flowAI)

                InboxView(taskService: taskService)
                    .tabItem {
                        Label("Inbox", systemImage: "tray")
                    }
                    .tag(AppState.Tab.inbox)

                BrowseView(taskService: taskService)
                    .tabItem {
                        Label("Browse", systemImage: "square.grid.2x2")
                    }
                    .tag(AppState.Tab.browse)
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(authManager)
        }
        .onAppear {
            taskService = TaskService(modelContext: modelContext)
        }
    }
}
