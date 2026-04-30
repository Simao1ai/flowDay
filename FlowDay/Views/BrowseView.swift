// BrowseView.swift
// FlowDay
//
// Browse tab — full project list, favorites, filters & labels access,
// templates, and search. Matches Todoist's Browse tab but with FlowDay's
// warm aesthetic and unique features.

import SwiftUI
import SwiftData

struct BrowseView: View {
    let taskService: TaskService?

    @Environment(\.modelContext) private var modelContext

    private var proAccess: ProAccessManager { .shared }
    @State private var showProUpgrade = false
    @Query
    private var projectsRaw: [FDProject]

    private var projects: [FDProject] {
        projectsRaw.sorted { $0.sortOrder < $1.sortOrder }
    }

    @State private var showFiltersLabels = false
    @State private var showTemplates = false
    @State private var showSettings = false
    @State private var showCreateProject = false
    @State private var showSearch = false
    @State private var expandFavorites = true
    @State private var expandProjects = true
    @State private var selectedProject: FDProject?
    @State private var showManageProjects = false
    @State private var selectedFilter: SmartFilter?
    @State private var showCollaborate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    quickActions
                    smartFiltersSection
                    if !favoriteProjects.isEmpty { favoritesSection }
                    projectsSection
                    sharedProjectsSection
                    bottomActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showFiltersLabels) { FiltersLabelsView() }
            .sheet(isPresented: $showTemplates) { TemplatesView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCreateProject) { CreateProjectSheet() }
            .sheet(isPresented: $showSearch) { SearchView(taskService: taskService) }
            .sheet(isPresented: $showManageProjects) { ManageProjectsView() }
            .sheet(isPresented: $showCollaborate) {
                CollaborateView(projectName: "")
            }
            .sheet(item: $selectedProject) { project in
                ProjectDetailView(project: project, taskService: taskService)
            }
            .sheet(item: $selectedFilter) { filter in
                SmartFilterView(filter: filter, taskService: taskService)
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView(highlightedFeature: .smartFilters)
            }
        }
    }

    // MARK: - Smart Filters

    private var smartFiltersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Smart Filters")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                if !proAccess.isFeatureAvailable(.smartFilters) {
                    Spacer()
                    proTag
                }
            }

            if proAccess.isFeatureAvailable(.smartFilters) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(SmartFilter.allCases) { filter in
                        smartFilterCard(filter)
                    }
                }
            } else {
                Button { showProUpgrade = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.fdAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Filters — Pro")
                                .font(.fdCaptionBold)
                                .foregroundStyle(Color.fdText)
                            Text("Filter by overdue, high priority, no date, and more")
                                .font(.fdMicro)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(16)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var proTag: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.fdAccent)
            .clipShape(Capsule())
    }

    private func smartFilterCard(_ filter: SmartFilter) -> some View {
        Button {
            Haptics.tap()
            selectedFilter = filter
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(filter.tint.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: filter.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(filter.tint)
                }
                Text(filter.title)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fdBorderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdAccentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text("S")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("FlowDay")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                Text("Free Plan")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdGreen)
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 0) {
            quickActionRow(icon: "magnifyingglass", title: "Search", color: .fdTextSecondary) {
                showSearch = true
            }
            Divider().padding(.leading, 52)
            quickActionRow(icon: "line.3.horizontal.decrease.circle", title: "Filters & Labels", color: .fdTextSecondary) {
                showFiltersLabels = true
            }
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private func quickActionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expandFavorites.toggle() } } label: {
                HStack {
                    Text("Favorites")
                        .font(.fdTitle3)
                        .foregroundStyle(Color.fdText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                        .rotationEffect(.degrees(expandFavorites ? 0 : -90))
                }
            }

            if expandFavorites {
                VStack(spacing: 0) {
                    ForEach(favoriteProjects) { project in
                        projectRow(project: project)
                        if project.id != favoriteProjects.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
    }

    // MARK: - My Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { withAnimation(.easeInOut(duration: 0.2)) { expandProjects.toggle() } } label: {
                    HStack {
                        Text("My Projects")
                            .font(.fdTitle3)
                            .foregroundStyle(Color.fdText)
                        Spacer()
                    }
                }

                Button { showCreateProject = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fdAccent)
                        .frame(width: 30, height: 30)
                        .background(Color.fdAccentLight)
                        .clipShape(Circle())
                }

                Button { withAnimation(.easeInOut(duration: 0.2)) { expandProjects.toggle() } } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                        .rotationEffect(.degrees(expandProjects ? 0 : -90))
                }
            }

            if expandProjects {
                VStack(spacing: 0) {
                    ForEach(activeProjects) { project in
                        projectRow(project: project)
                        if project.id != activeProjects.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }

                    Divider().padding(.leading, 52)

                    // Manage Projects row
                    Button {
                        showManageProjects = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.fdTextMuted)
                                .frame(width: 28)
                            Text("Manage Projects")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdTextMuted)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
    }

    private func projectRow(project: FDProject) -> some View {
        Button {
            selectedProject = project
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 10, height: 10)
                    .frame(width: 28)

                Text(project.name)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)

                Spacer()

                Text("\(project.activeTasks.count)")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)

                // Mini progress bar
                progressBar(rate: project.completionRate)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func progressBar(rate: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fdBorderLight)
                .frame(width: 40, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fdGreen)
                .frame(width: max(0, 40 * rate), height: 4)
        }
    }

    // MARK: - Shared Projects

    private var sharedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Projects")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)

            Button {
                Haptics.tap()
                showCollaborate = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.fdBlue.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fdBlue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Collaborate")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                        Text("Share projects, invite teammates")
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 0) {
            bottomActionRow(icon: "sparkles", title: "Browse Templates", color: .fdAccent) {
                showTemplates = true
            }
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private func bottomActionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
    }

    // MARK: - Data Helpers

    private var activeProjects: [FDProject] {
        projects.filter { !$0.isArchived }
    }

    private var favoriteProjects: [FDProject] {
        projects.filter { $0.isFavorite && !$0.isArchived }
    }
}

// CreateProjectSheet is defined in ProjectSidebarView.swift and shared across views.

// MARK: - Manage Projects View

struct ManageProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query
    private var projectsRaw: [FDProject]

    private var projects: [FDProject] {
        projectsRaw.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active Projects") {
                    ForEach(projects.filter { !$0.isArchived }) { project in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: project.colorHex))
                                .frame(width: 12, height: 12)
                            Text(project.name)
                                .font(.fdBody)
                            Spacer()
                            Text("\(project.tasks.count) tasks")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                    .onDelete { indexSet in
                        let active = projects.filter { !$0.isArchived }
                        for index in indexSet {
                            let project = active[index]
                            project.isArchived = true
                        }
                        try? modelContext.save()
                    }
                    .onMove { from, to in
                        var active = projects.filter { !$0.isArchived }
                        active.move(fromOffsets: from, toOffset: to)
                        for (i, project) in active.enumerated() {
                            project.sortOrder = i
                        }
                        try? modelContext.save()
                    }
                }

                if !projects.filter({ $0.isArchived }).isEmpty {
                    Section("Archived") {
                        ForEach(projects.filter { $0.isArchived }) { project in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: project.colorHex).opacity(0.5))
                                    .frame(width: 12, height: 12)
                                Text(project.name)
                                    .font(.fdBody)
                                    .foregroundStyle(Color.fdTextMuted)
                                Spacer()
                                Button("Restore") {
                                    project.isArchived = false
                                    try? modelContext.save()
                                }
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdAccent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.fdAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(Color.fdAccent)
                }
            }
        }
    }
}
