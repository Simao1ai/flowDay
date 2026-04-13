// RootView.swift
// FlowDay
//
// The main navigation shell with warm themed tabs.

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var taskService: TaskService?
    @State private var calendarService = CalendarService()
    @State private var showEnergyCheckIn = true
    @State private var showAIAssistant = false

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

                // AI Assistant floating tab — opens as sheet
                Color.clear
                    .tabItem {
                        Label("Flow AI", systemImage: "sparkles")
                    }
                    .tag(AppState.Tab.flowAI)

                HabitsView()
                    .tabItem {
                        Label("Habits", systemImage: "flame")
                    }
                    .tag(AppState.Tab.habits)

                BrowseView(taskService: taskService)
                    .tabItem {
                        Label("Browse", systemImage: "text.justify.leading")
                    }
                    .tag(AppState.Tab.browse)
            }
            .tint(Color.fdAccent)
            .onChange(of: appState.selectedTab) { oldValue, newValue in
                if newValue == .flowAI {
                    // Redirect: open AI sheet instead of staying on empty tab
                    showAIAssistant = true
                    appState.selectedTab = oldValue
                }
            }
            .sheet(isPresented: $showAIAssistant) {
                AIAssistantView()
            }

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
        .onAppear {
            taskService = TaskService(modelContext: modelContext)
            seedDataIfNeeded()
        }
    }

    // MARK: - Seed sample data on first launch

    private func seedDataIfNeeded() {
        guard !appState.hasSeededData else { return }
        appState.hasSeededData = true

        let descriptor = FetchDescriptor<FDTask>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        seedProjects()
    }

    private func seedProjects() {
        let workProject = FDProject(name: "Work", colorHex: "#5B8FD4", iconName: "briefcase")
        let personalProject = FDProject(name: "Personal", colorHex: "#5BA065", iconName: "person")
        let flowDayProject = FDProject(name: "FlowDay", colorHex: "#D4713B", iconName: "sparkles")
        modelContext.insert(workProject)
        modelContext.insert(personalProject)
        modelContext.insert(flowDayProject)

        seedTasks(work: workProject, personal: personalProject, flowDay: flowDayProject)
        seedHabits()

        try? modelContext.save()
    }

    private func seedTasks(work: FDProject, personal: FDProject, flowDay: FDProject) {
        let today = Date.now
        let cal = Calendar.current

        let task1 = FDTask(
            title: "Review Q2 marketing plan",
            notes: "Focus on social media strategy section",
            dueDate: today,
            scheduledTime: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
            estimatedMinutes: 45,
            priority: .high,
            project: work
        )
        modelContext.insert(task1)

        let task2 = FDTask(
            title: "Design onboarding flow",
            notes: "Wireframes for new user experience",
            dueDate: today,
            scheduledTime: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today),
            estimatedMinutes: 60,
            priority: .urgent,
            project: flowDay
        )
        modelContext.insert(task2)

        let sub1 = FDSubtask(title: "Sketch welcome screen", sortOrder: 0, parentTask: task2)
        let sub2 = FDSubtask(title: "Define user segments", sortOrder: 1, parentTask: task2)
        let sub3 = FDSubtask(title: "Create prototype in Figma", sortOrder: 2, parentTask: task2)
        task2.subtasks = [sub1, sub2, sub3]

        let task3 = FDTask(
            title: "Grocery run",
            notes: "Trader Joe's",
            dueDate: today,
            scheduledTime: cal.date(bySettingHour: 17, minute: 0, second: 0, of: today),
            estimatedMinutes: 30,
            priority: .medium,
            project: personal
        )
        modelContext.insert(task3)

        let task4 = FDTask(
            title: "Read chapter 5 of Atomic Habits",
            priority: .none,
            project: personal
        )
        modelContext.insert(task4)

        let task5 = FDTask(
            title: "Send invoice to client",
            dueDate: cal.date(byAdding: .day, value: 1, to: today),
            priority: .high,
            project: work
        )
        modelContext.insert(task5)

        let task6 = FDTask(
            title: "Plan weekend trip",
            dueDate: cal.date(byAdding: .day, value: 3, to: today),
            priority: .none,
            project: personal
        )
        modelContext.insert(task6)
    }

    private func seedHabits() {
        let habit1 = FDHabit(name: "Meditate", emoji: "🧘", colorHex: "#8B6BBF",
                             frequency: .daily, preferredTime: .morning)
        let habit2 = FDHabit(name: "Exercise", emoji: "💪", colorHex: "#D4713B",
                             frequency: .weekdays, preferredTime: .morning)
        let habit3 = FDHabit(name: "Read", emoji: "📚", colorHex: "#5B8FD4",
                             frequency: .daily, preferredTime: .evening)
        let habit4 = FDHabit(name: "Journal", emoji: "✍️", colorHex: "#5BA065",
                             frequency: .daily, preferredTime: .evening)
        modelContext.insert(habit1)
        modelContext.insert(habit2)
        modelContext.insert(habit3)
        modelContext.insert(habit4)
    }
}
