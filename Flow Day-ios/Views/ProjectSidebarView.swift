// ProjectSidebarView.swift
// FlowDay
//
// Todoist screenshot 3: sidebar with Inbox, Today, Upcoming,
// My Projects (expandable), and project hierarchy.
// FlowDay adds: completion rates, color dots, quick project create.

import SwiftUI
import SwiftData

struct ProjectSidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @Query(sort: [SortDescriptor(\FDProject.sortOrder)])
    private var projects: [FDProject]

    @State private var showCreateProject = false
    @State private var showSettings = false
    @State private var projectsExpanded = true
    @State private var favoritesExpanded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // User profile header
                    profileHeader

                    Divider().padding(.vertical, 8)

                    // Navigation items
                    navigationSection

                    Divider().padding(.vertical, 8)

                    // Favorites
                    let favorites = projects.filter(\.isFavorite)
                    if !favorites.isEmpty {
                        favoritesSection(favorites)
                        Divider().padding(.vertical, 8)
                    }

                    // My Projects
                    projectsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.fdBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                }
            }
            .sheet(isPresented: $showCreateProject) {
                CreateProjectSheet()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.fdAccent, Color.fdPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay {
                    Text("S")
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("FlowDay")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Text("Free Plan")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 2) {
            navRow(icon: "tray", label: "Inbox", tab: .inbox, badge: nil)
            navRow(icon: "sun.max", label: "Today", tab: .today, badge: nil)
            navRow(icon: "calendar", label: "Upcoming", tab: .upcoming, badge: nil)
            navRow(icon: "flame", label: "Habits", tab: .habits, badge: nil)
        }
    }

    private func navRow(icon: String, label: String, tab: AppState.Tab, badge: Int?) -> some View {
        Button {
            appState.selectedTab = tab
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(tab == appState.selectedTab ? Color.fdAccent : Color.fdTextSecondary)
                    .frame(width: 24)

                Text(label)
                    .font(.fdBody)
                    .foregroundStyle(tab == appState.selectedTab ? Color.fdAccent : Color.fdText)

                Spacer()

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                tab == appState.selectedTab
                    ? Color.fdAccent.opacity(0.08)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Favorites

    private func favoritesSection(_ favorites: [FDProject]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title: "Favorites", isExpanded: $favoritesExpanded)

            if favoritesExpanded {
                ForEach(favorites) { project in
                    projectRow(project)
                }
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                sectionHeader(title: "My Projects", isExpanded: $projectsExpanded)

                Spacer()

                Button {
                    showCreateProject = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }

            if projectsExpanded {
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func sectionHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.fdTextMuted)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                Text(title)
                    .fdSectionHeader()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }

    private func projectRow(_ project: FDProject) -> some View {
        Button {
            // Navigate to project view — Phase 2
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 10, height: 10)

                Text(project.name)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                // Task count
                let activeCount = project.activeTasks.count
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }

                // Completion mini bar
                if project.completionRate > 0 {
                    miniProgressBar(project.completionRate, color: Color(hex: project.colorHex))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func miniProgressBar(_ progress: Double, color: Color) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fdBorderLight)
                .frame(width: 32, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: CGFloat(32 * progress), height: 4)
        }
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selectedColor = "#D4713B"
    @State private var selectedIcon = "folder"

    private let colorOptions = [
        "#D4713B", "#5B8FD4", "#5BA065", "#8B6BBF",
        "#D4A73B", "#D45B5B", "#5BBFD4", "#BF6B8B"
    ]

    private let iconOptions = [
        "folder", "briefcase", "person", "leaf", "hammer",
        "book", "star", "heart", "lightbulb", "graduationcap"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .fdSectionHeader()
                    TextField("Project name", text: $name)
                        .font(.fdBody)
                        .padding(14)
                        .background(Color.fdSurfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR")
                        .fdSectionHeader()
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColor == hex {
                                            Circle()
                                                .stroke(.white, lineWidth: 2)
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                            }
                        }
                    }
                }

                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("ICON")
                        .fdSectionHeader()
                    HStack(spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        selectedIcon == icon
                                            ? Color.fdAccent.opacity(0.12)
                                            : Color.fdSurfaceHover
                                    )
                                    .foregroundStyle(
                                        selectedIcon == icon
                                            ? Color.fdAccent
                                            : Color.fdTextSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Color.fdBackground)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        guard !name.isEmpty else { return }
                        let project = FDProject(name: name, colorHex: selectedColor, iconName: selectedIcon)
                        modelContext.insert(project)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fdAccent)
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
