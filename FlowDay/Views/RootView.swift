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
    @State private var focusTimerService = FocusTimerService()
    @State private var calendarService = CalendarService()
    @State private var gamification = GamificationService.shared
    @State private var showEnergyCheckIn = true
    @State private var showSettings = false
    @State private var showWhatsNew = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion: String = ""

    var body: some View {
        @Bindable var state = appState

        // The Flow AI tab is virtual: tapping it opens a sheet rather than
        // switching tabs, so the user keeps their current screen underneath.
        let tabBinding = Binding<AppState.Tab>(
            get: { state.selectedTab },
            set: { newTab in
                if newTab == .flowAI {
                    state.showFlowAI = true
                } else {
                    state.selectedTab = newTab
                }
            }
        )

        ZStack {
            TabView(selection: tabBinding) {
                TodayView(taskService: taskService, calendarService: calendarService)
                        .environment(focusTimerService)
                    .tabItem {
                        Label("Today", systemImage: "sun.max")
                    }
                    .tag(AppState.Tab.today)

                UpcomingView(taskService: taskService)
                    .tabItem {
                        Label("Upcoming", systemImage: "calendar")
                    }
                    .tag(AppState.Tab.upcoming)

                // Flow AI — center tab; tap is intercepted to present a sheet.
                Color.clear
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
        .sheet(isPresented: $showWhatsNew) {
            NavigationStack { WhatsNewView() }
        }
        .sheet(isPresented: $state.showFlowAI) {
            AIAssistantView()
        }
        .environment(gamification)
        .onAppear {
            taskService = TaskService(modelContext: modelContext)
            gamification.checkAndUpdateStreak()
            if lastSeenWhatsNewVersion != WhatsNewView.currentVersion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showWhatsNew = true
                }
            }

            // Request calendar access and fetch events
            Task {
                let granted = await calendarService.requestAccess()
                if granted {
                    await MainActor.run {
                        calendarService.fetchTodayEvents()
                    }
                }
            }
        }
    }
}
