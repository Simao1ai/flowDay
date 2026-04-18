// TemplatesView.swift
// FlowDay
//
// Massive template expansion: Featured, Industries (Real Estate, Freelance, Students, Healthcare, Construction, Content Creators),
// Life & Personal, Productivity Methods, and AI Template Generator.
// Industry-specific templates + AI generation = beats Todoist on templates + stays original.

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: TemplateTab = .featured
    @State private var searchText = ""
    @State private var aiPrompt = ""
    @State private var isGeneratingTemplate = false
    @State private var generationError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                ScrollView {
                    VStack(spacing: 24) {
                        tabContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.fdBackground)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.fdText)
                            .frame(width: 32, height: 32)
                            .background(Color.fdSurfaceHover)
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { searchBar }
            .overlay {
                if showTemplateApplied, let name = appliedTemplateName {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.fdGreen)
                        Text("\(name) added!")
                            .font(.fdTitle3)
                            .foregroundStyle(Color.fdText)
                        Text("Project created with starter tasks")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.1), radius: 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showTemplateApplied)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TemplateTab.allCases, id: \.self) { tab in
                    tabButton(tab: tab)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func tabButton(tab: TemplateTab) -> some View {
        Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.title)
                    .font(.fdCaptionBold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedTab == tab ? Color.fdAccent : Color.fdSurfaceHover)
            .foregroundStyle(selectedTab == tab ? .white : Color.fdTextSecondary)
            .clipShape(Capsule())
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .featured:
            featuredContent
        case .industries:
            industriesContent
        case .personal:
            personalContent
        case .productivity:
            productivityContent
        case .aiGenerate:
            aiGenerateContent
        }
    }

    // MARK: - Featured Tab

    private var featuredContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero Card: Energy-Aware Day
            heroCard(
                template: TemplateItem(
                    name: "Energy-Aware Day",
                    description: "Let AI schedule your tasks based on energy levels — FlowDay exclusive.",
                    icon: "bolt.fill",
                    color: Color.fdAccent,
                    category: "featured",
                    projects: 1, labels: 2, filters: 1
                )
            )

            // Featured grid
            VStack(alignment: .leading, spacing: 12) {
                Text("More Featured Templates")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(featuredTemplates) { tmpl in
                        standardTemplateCard(template: tmpl)
                    }
                }
            }
        }
    }

    private func heroCard(template: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(template.color)
                Spacer()
            }

            Text(template.name)
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)

            Text(template.description)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .lineLimit(2)

            Button {
                applyTemplate(template)
            } label: {
                Text("Use Template")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.fdAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.fdAccentLight, Color.fdSurface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    // MARK: - Industries Tab

    private var industriesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Real Estate
            industrySection(
                emoji: "🏠",
                title: "Real Estate",
                icon: "building.columns",
                templates: realEstateTemplates
            )

            // Freelance & Agency
            industrySection(
                emoji: "💼",
                title: "Freelance & Agency",
                icon: "laptopcomputer",
                templates: freelanceTemplates
            )

            // Small Business
            industrySection(
                emoji: "🏪",
                title: "Small Business",
                icon: "storefront",
                templates: smallBusinessTemplates
            )

            // Sales & Marketing
            industrySection(
                emoji: "📣",
                title: "Sales & Marketing",
                icon: "megaphone",
                templates: salesMarketingTemplates
            )

            // Software & Engineering
            industrySection(
                emoji: "💻",
                title: "Software & Engineering",
                icon: "chevron.left.forwardslash.chevron.right",
                templates: softwareTemplates
            )

            // Students
            industrySection(
                emoji: "🎓",
                title: "Students",
                icon: "graduationcap",
                templates: studentTemplates
            )

            // Healthcare
            industrySection(
                emoji: "🏥",
                title: "Healthcare",
                icon: "cross.case",
                templates: healthcareTemplates
            )

            // Legal & Compliance
            industrySection(
                emoji: "⚖️",
                title: "Legal & Compliance",
                icon: "building.columns",
                templates: legalTemplates
            )

            // Finance & Accounting
            industrySection(
                emoji: "💰",
                title: "Finance & Accounting",
                icon: "dollarsign.circle",
                templates: financeTemplates
            )

            // Education & Teaching
            industrySection(
                emoji: "📚",
                title: "Education & Teaching",
                icon: "book",
                templates: educationTemplates
            )

            // Construction & Trades
            industrySection(
                emoji: "🏗️",
                title: "Construction & Trades",
                icon: "hammer",
                templates: constructionTemplates
            )

            // Content Creators
            industrySection(
                emoji: "📱",
                title: "Content Creators",
                icon: "video",
                templates: contentCreatorTemplates
            )

            // Events & Planning
            industrySection(
                emoji: "🎉",
                title: "Events & Planning",
                icon: "party.popper",
                templates: eventsTemplates
            )

            // Nonprofit & Community
            industrySection(
                emoji: "🤝",
                title: "Nonprofit & Community",
                icon: "heart.circle",
                templates: nonprofitTemplates
            )
        }
    }

    private func industrySection(emoji: String, title: String, icon: String, templates: [TemplateItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(emoji) \(title)")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Text("\(templates.count) templates")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.fdSurfaceHover)
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                ForEach(templates) { tmpl in
                    industryTemplateCard(template: tmpl)
                }
            }
        }
    }

    private func industryTemplateCard(template: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Left accent bar
                Rectangle()
                    .fill(template.color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: template.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(template.color)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(template.color.opacity(0.1))
                            )

                        Text(template.name)
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdText)

                        Spacer()
                    }

                    Text(template.description)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    applyTemplate(template)
                } label: {
                    Text("Use")
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.fdAccentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Life & Personal Tab

    private var personalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(personalTemplates) { tmpl in
                    standardTemplateCard(template: tmpl)
                }
            }
        }
    }

    // MARK: - Productivity Methods Tab

    private var productivityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(productivityMethods) { method in
                    methodCard(method: method)
                }
            }
        }
    }

    private func methodCard(method: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: method.icon)
                .font(.system(size: 28))
                .foregroundStyle(method.color)
                .frame(height: 40)

            Text(method.name)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
                .lineLimit(2)

            Text(method.description)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .lineLimit(3)

            Spacer()

            Button {
                applyTemplate(method)
            } label: {
                Text("Use")
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(method.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - AI Generate Tab

    private var aiGenerateContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // AI Generator Hero
            VStack(alignment: .center, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.fdAccent)
                    Text("AI Template Generator")
                        .font(.fdTitle3)
                        .foregroundStyle(Color.fdText)
                }

                Text("Describe what you need and FlowDay AI will create a custom template")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // Input Section
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $aiPrompt)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.fdBorder, lineWidth: 1)
                        )

                    if aiPrompt.isEmpty {
                        VStack(alignment: .leading) {
                            Text("e.g., I'm launching a podcast and need to track episodes from recording to publication...")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                                .padding(16)
                            Spacer()
                        }
                    }
                }

                if let error = generationError {
                    Text(error)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                Button {
                    Task { await generateAITemplate() }
                } label: {
                    if isGeneratingTemplate {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Generating…")
                        }
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.fdAccent.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Template")
                        }
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.fdAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .disabled(aiPrompt.trimmingCharacters(in: .whitespaces).isEmpty || isGeneratingTemplate)
            }

            // Recently Generated
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("Recently Generated")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.fdAccent)
                }

                VStack(spacing: 10) {
                    aiGeneratedCard(
                        template: TemplateItem(
                            name: "Podcast Launch",
                            description: "From first episode concept to listener growth strategy",
                            icon: "waveform",
                            color: Color.fdPurple,
                            category: "AI Generated",
                            projects: 1, labels: 2, filters: 1
                        )
                    )

                    aiGeneratedCard(
                        template: TemplateItem(
                            name: "App Launch Checklist",
                            description: "Product roadmap, beta testing, launch day coordination",
                            icon: "square.stack.3d.up",
                            color: Color.fdBlue,
                            category: "AI Generated",
                            projects: 1, labels: 2, filters: 1
                        )
                    )
                }
            }
        }
    }

    private func aiGeneratedCard(template: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(template.color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: template.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(template.color)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(template.color.opacity(0.1))
                            )

                        Text(template.name)
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdText)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("AI")
                                .font(.fdMicroBold)
                        }
                        .foregroundStyle(Color.fdAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.fdAccentLight)
                        .clipShape(Capsule())
                    }

                    Text(template.description)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Standard Template Card

    private func standardTemplateCard(template: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: template.icon)
                .font(.system(size: 24))
                .foregroundStyle(template.color)
                .frame(height: 32)

            Text(template.name)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
                .lineLimit(1)

            Text(template.description)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .lineLimit(2)

            Spacer()

            Button {
                applyTemplate(template)
            } label: {
                Text("Use")
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(template.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.fdTextMuted)
            Text("Search Templates")
                .font(.fdBody)
                .foregroundStyle(Color.fdTextMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    @State private var appliedTemplateName: String?
    @State private var showTemplateApplied = false

    // MARK: - AI Template Generation

    /// JSON shape returned by the Edge Function for the templateGenerator feature.
    private struct AITemplateResponse: Decodable {
        let name: String
        let description: String
        let icon: String
        let colorHex: String
        let tasks: [AITemplateTask]
    }

    private struct AITemplateTask: Decodable {
        let title: String
        let priority: Int
        let estimatedMinutes: Int
        let notes: String?
    }

    @MainActor
    private func generateAITemplate() async {
        let prompt = aiPrompt.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }

        isGeneratingTemplate = true
        generationError = nil

        defer { isGeneratingTemplate = false }

        let userMessage = """
        Create a task template for this project:
        "\(prompt)"

        Return ONLY a JSON object — no markdown, no prose.
        """

        do {
            let raw = try await ClaudeClient.shared.chat(
                feature: .templateGenerator,
                messages: [LLMMessage(role: .user, content: userMessage)],
                temperature: 0.8,
                maxTokens: 2048
            )

            // Strip markdown code fences if present
            let cleaned = extractJSON(from: raw)

            guard let data = cleaned.data(using: .utf8),
                  let aiTemplate = try? JSONDecoder().decode(AITemplateResponse.self, from: data) else {
                generationError = "Couldn't parse the AI response. Try again."
                return
            }

            // Create FDProject
            let project = FDProject(
                name: aiTemplate.name,
                colorHex: aiTemplate.colorHex,
                iconName: aiTemplate.icon
            )
            modelContext.insert(project)

            // Create FDTask for each AI-suggested task
            for (index, aiTask) in aiTemplate.tasks.enumerated() {
                let priority: TaskPriority
                switch aiTask.priority {
                case 1: priority = .urgent
                case 2: priority = .high
                case 3: priority = .medium
                default: priority = .none
                }

                let task = FDTask(
                    title: aiTask.title,
                    notes: aiTask.notes ?? "",
                    estimatedMinutes: aiTask.estimatedMinutes,
                    priority: priority,
                    project: project
                )
                task.sortOrder = index
                modelContext.insert(task)

                // TODO: Supabase sync via REST API
            }

            try? modelContext.save()

            // TODO: Supabase template save and project sync via REST API

            appliedTemplateName = aiTemplate.name
            showTemplateApplied = true
            aiPrompt = ""

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }

        } catch let err as ClaudeClientError {
            generationError = err.localizedDescription
        } catch {
            generationError = "AI generation failed. Check your connection and try again."
        }
    }

    /// Extract the JSON object from a string that may contain markdown code fences.
    private func extractJSON(from text: String) -> String {
        var s = text
        if let start = s.range(of: "```json") {
            s.removeSubrange(...start.lowerBound)
            if let end = s.range(of: "```") { s.removeSubrange(end.lowerBound...) }
        } else if let start = s.range(of: "```") {
            s.removeSubrange(...start.lowerBound)
            if let end = s.range(of: "```") { s.removeSubrange(end.lowerBound...) }
        }
        guard let jsonStart = s.firstIndex(of: "{"),
              let jsonEnd = s.lastIndex(of: "}") else { return s }
        return String(s[jsonStart...jsonEnd])
    }

    // MARK: - Apply Template

    private func applyTemplate(_ template: TemplateItem) {
        let colorHex = template.color.toHex() ?? "#D4713B"
        let project = FDProject(name: template.name, colorHex: colorHex, iconName: template.icon)
        modelContext.insert(project)

        // Generate starter tasks for the template
        let tasks = templateTasks(for: template)
        for (index, taskTitle) in tasks.enumerated() {
            let task = FDTask(
                title: taskTitle,
                priority: index == 0 ? .high : .medium,
                project: project
            )
            modelContext.insert(task)
        }

        try? modelContext.save()
        appliedTemplateName = template.name
        showTemplateApplied = true

        // Auto-dismiss after brief confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private func templateTasks(for template: TemplateItem) -> [String] {
        // Each template gets unique, actionable starter tasks
        switch template.name {

        // MARK: Featured
        case "Energy-Aware Day":
            return ["Log your energy level for morning, afternoon & evening", "Identify your peak energy window this week", "Schedule your hardest task during peak energy", "Move low-effort tasks to your energy dip hours", "Review & rate how the energy-matched day felt"]
        case "AI Task Breakdown":
            return ["Define one big goal you want to accomplish", "Let AI break it into 5-7 subtasks", "Assign priorities and deadlines to each subtask", "Complete the first subtask today", "Review progress and adjust the plan"]
        case "Weekly Review Ritual":
            return ["Review all completed tasks from this week", "Move unfinished tasks to next week or archive them", "Celebrate 3 wins from the past week", "Set your top 3 priorities for next week", "Clear your inbox and process all loose items"]
        case "Morning Power Hour":
            return ["Review today's schedule and top 3 priorities", "Complete your most important task first", "Process and respond to urgent messages only", "Plan your time blocks for the rest of the day", "Set one intention for how you want to feel today"]
        case "Focus Sprint":
            return ["Choose one high-priority task to deep work on", "Set a 45-minute focus timer with no distractions", "Take a 10-minute break — walk or stretch", "Do a second 45-minute focus session", "Log what you accomplished and how it felt"]

        // MARK: Real Estate
        case "Open House Prep":
            return ["Stage property & declutter every room", "Print marketing materials & sign-in sheets", "Set up signage and directional signs", "Prepare refreshments & background music", "Follow up with all attendees within 24 hours"]
        case "Listing Launch":
            return ["Schedule professional photography", "Write compelling listing description", "Submit to MLS & syndicate portals", "Create social media campaign", "Schedule first open house"]
        case "Buyer Pipeline":
            return ["Initial consultation & needs assessment", "Set up automated property search alerts", "Schedule property showings for the week", "Pull comparable sales for top picks", "Prepare & submit offer with cover letter"]
        case "Transaction Coordinator":
            return ["Collect signed purchase agreement", "Order title search & home inspection", "Coordinate with lender on financing timeline", "Review all disclosures & compliance documents", "Schedule closing & final walkthrough"]

        // MARK: Freelance & Agency
        case "Client Onboarding":
            return ["Send welcome packet & signed contract", "Schedule 30-min kickoff call", "Set up shared project workspace (Notion, Drive, etc.)", "Define communication cadence & channels", "Deliver project timeline with milestones"]
        case "Project Sprint":
            return ["Define sprint goal & deliverables", "Break deliverables into daily tasks", "Set up progress check-in for mid-sprint", "Complete all deliverables before sprint end", "Send client update with completed work"]
        case "Invoice & Follow-up":
            return ["Generate invoice from completed milestones", "Send invoice with payment instructions", "Set 7-day payment reminder", "Follow up on overdue invoices", "Log payment received & update books"]

        // MARK: Students
        case "Semester Planner":
            return ["Add all class times to your calendar", "Map out every assignment due date from syllabi", "Block weekly study sessions for each course", "Set up a note-taking system per class", "Schedule monthly check-ins on grade progress"]
        case "Research Paper":
            return ["Choose topic & get advisor approval", "Gather 10+ sources and annotate key findings", "Write thesis statement & outline", "Draft body paragraphs section by section", "Revise, format citations, and proofread"]
        case "Exam Prep Sprint":
            return ["Gather all study materials & past exams", "Create condensed review sheets per topic", "Practice with timed mock exams", "Review mistakes and weak areas", "Do a light review the day before — no cramming"]

        // MARK: Healthcare
        case "Patient Follow-up":
            return ["Review patient chart & recent visit notes", "Call patient to check on recovery progress", "Update care plan based on follow-up", "Schedule next appointment if needed", "Document follow-up notes in patient record"]
        case "Shift Handoff":
            return ["Review current patient statuses", "Note any critical changes or new orders", "Document pending tasks for incoming shift", "Brief incoming staff on priority patients", "Confirm handoff is complete with sign-off"]
        case "Continuing Education":
            return ["Check CE credit requirements for this cycle", "Research available courses & conferences", "Register for at least one course", "Complete coursework and take assessment", "Submit proof of completion for credits"]

        // MARK: Construction & Trades
        case "Job Site Checklist":
            return ["Complete morning safety walkthrough", "Verify all materials are on-site", "Check permits & inspection schedule", "Take progress photos and document work", "Update project timeline & flag delays"]
        case "Estimate & Bid":
            return ["Visit site and take measurements", "List all materials, labor & equipment needed", "Get supplier quotes for materials", "Calculate total with markup and contingency", "Submit professional proposal to client"]

        // MARK: Content Creators
        case "Content Calendar":
            return ["Brainstorm 10 content ideas for the month", "Assign each idea a platform and publish date", "Create or source visuals for each post", "Write captions and hashtag sets", "Schedule all posts using your publishing tool"]
        case "Video Production":
            return ["Write script & create shot list", "Set up filming location & lighting", "Record all footage and B-roll", "Edit video with transitions, music & captions", "Upload, write description & schedule publish"]
        case "Brand Collaboration":
            return ["Research brand & align on deliverables", "Draft proposal with rates & timeline", "Create content per agreed brief", "Submit for brand review & approval", "Publish and send performance report"]

        // MARK: Small Business
        case "Business Launch Checklist":
            return ["Register business name & get EIN/licenses", "Set up business bank account", "Build simple website or landing page", "Create social media profiles", "Launch with an announcement post & email"]
        case "Inventory Management":
            return ["Audit current stock levels", "Identify low-stock and overstock items", "Place reorder for essential items", "Update inventory tracking system", "Set reorder alerts for top sellers"]
        case "Customer Feedback Loop":
            return ["Send post-purchase satisfaction survey", "Collect and categorize all feedback", "Identify top 3 recurring complaints", "Create action plan for each issue", "Follow up with customers on changes made"]

        // MARK: Sales & Marketing
        case "Product Launch":
            return ["Finalize launch date & key messaging", "Create landing page & marketing assets", "Set up email drip campaign", "Schedule social media launch sequence", "Monitor launch metrics & respond to feedback"]
        case "Lead Nurture Sequence":
            return ["Segment leads by interest & stage", "Write 5-email nurture sequence", "Set up automated send schedule", "Track open rates & click-throughs", "Follow up personally with hot leads"]
        case "Campaign Tracker":
            return ["Define campaign goal & target KPIs", "Launch ads across chosen channels", "Monitor daily spend & performance", "A/B test creative and copy variations", "Compile final report with ROI analysis"]

        // MARK: Software & Engineering
        case "Sprint Planning":
            return ["Review backlog & prioritize by impact", "Estimate story points for top items", "Assign tasks to team members", "Set sprint goal & define done criteria", "Schedule daily standup cadence"]
        case "Bug Triage":
            return ["Collect all new bug reports", "Reproduce and confirm each bug", "Assign severity: critical, high, medium, low", "Assign bugs to owners with deadlines", "Verify fixes and close resolved bugs"]
        case "Feature Rollout":
            return ["Write feature spec & get stakeholder sign-off", "Implement feature with tests", "Deploy to staging & run QA", "Create feature flag for gradual rollout", "Monitor metrics post-launch & iterate"]

        // MARK: Legal & Compliance
        case "Contract Review":
            return ["Read full contract and flag key clauses", "Check for liability & indemnification terms", "Verify payment terms & deadlines", "Note any non-compete or exclusivity clauses", "Send summary with recommended changes"]
        case "Compliance Audit":
            return ["Gather all required documentation", "Review against current regulatory requirements", "Identify gaps & non-compliance risks", "Create remediation plan with deadlines", "Submit audit report to stakeholders"]
        case "Case File Setup":
            return ["Open new case file with client details", "Collect all relevant documents & evidence", "Set key dates: filings, hearings, deadlines", "Draft initial strategy memo", "Schedule client update meeting"]

        // MARK: Finance & Accounting
        case "Monthly Close":
            return ["Reconcile all bank & credit card accounts", "Review and categorize pending transactions", "Post adjusting journal entries", "Generate P&L and balance sheet", "Send financial summary to stakeholders"]
        case "Tax Prep Checklist":
            return ["Gather all income documents (W-2s, 1099s)", "Compile deduction receipts & records", "Review last year's return for carryovers", "Complete and review tax forms", "File return and set up estimated payments"]
        case "Budget Planning":
            return ["Review last period's actuals vs. budget", "Identify areas of overspend & underspend", "Set targets for each category next period", "Build budget spreadsheet with projections", "Get approval & share with team"]

        // MARK: Events & Planning
        case "Event Planning":
            return ["Define event goals, theme & date", "Book venue and key vendors", "Create guest list & send invitations", "Plan event run-of-show timeline", "Post-event: send thank-yous & gather feedback"]
        case "Conference Prep":
            return ["Register & book travel and hotel", "Review speaker lineup & plan your schedule", "Prepare business cards & elevator pitch", "Set networking goals (meet 5 new people)", "Post-conference: follow up with new contacts"]
        case "Party Planner":
            return ["Set date, theme & guest count", "Book venue or prep hosting space", "Order food, drinks & decorations", "Create playlist & plan activities", "Send reminders 2 days before"]

        // MARK: Nonprofit & Community
        case "Fundraising Campaign":
            return ["Define fundraising goal & timeline", "Create campaign page & donation link", "Draft outreach emails & social posts", "Reach out to major donors personally", "Send thank-you notes & share impact report"]
        case "Volunteer Coordination":
            return ["Post volunteer opportunity & requirements", "Screen and confirm volunteers", "Create shift schedule & assignments", "Send briefing with logistics & expectations", "Collect feedback & thank volunteers"]
        case "Grant Application":
            return ["Research eligible grants & deadlines", "Gather required documents & data", "Write project narrative & budget justification", "Get internal review & sign-offs", "Submit application before deadline"]

        // MARK: Education & Teaching
        case "Lesson Plan Builder":
            return ["Define learning objectives for the unit", "Outline activities, materials & timing", "Create handouts or digital resources", "Plan assessment (quiz, project, discussion)", "Reflect on what worked after delivery"]
        case "Parent-Teacher Prep":
            return ["Review each student's progress & grades", "Note specific strengths & areas for growth", "Prepare talking points & examples", "Set up meeting schedule & send reminders", "Document action items from each meeting"]
        case "Classroom Setup":
            return ["Arrange desks & seating chart", "Set up bulletin boards & learning stations", "Organize supplies & label storage areas", "Test all tech (projector, tablets, Wi-Fi)", "Prepare first-day welcome activity"]

        // MARK: Life & Personal (unique per template)
        case "Home Renovation":
            return ["Choose room to start & set budget", "Research contractors & get 3 quotes", "Order materials & set delivery dates", "Supervise work & do daily progress check", "Final walkthrough & punch list"]
        case "Wedding Planning":
            return ["Set budget & create guest list", "Book venue & caterer", "Choose photographer, florist & DJ", "Send invitations & track RSVPs", "Create day-of timeline & assign roles"]
        case "Move & Relocate":
            return ["Declutter & decide what to keep, donate, toss", "Book movers or reserve a truck", "Pack room by room with labeled boxes", "Transfer utilities, mail & subscriptions", "Unpack essentials first & settle in"]
        case "Travel Planner":
            return ["Choose destination & set travel dates", "Book flights & accommodation", "Plan daily itinerary with key activities", "Create packing list & check documents", "Download offline maps & confirm reservations"]
        case "Fitness Journey":
            return ["Set specific fitness goal (weight, strength, endurance)", "Create weekly workout schedule", "Meal prep for the week (protein, veggies, carbs)", "Track workouts & log progress photos", "Weekly check-in: adjust plan based on results"]
        case "Side Hustle Launch":
            return ["Validate your idea with 5 potential customers", "Set up a simple landing page or storefront", "Create your first product or service offering", "Post your launch on social media & tell friends", "Get your first paying customer this week"]
        case "Digital Detox Week":
            return ["Set screen time limits on all devices", "Delete or log out of social media apps", "Replace phone time with a book or hobby", "Go for a daily 30-minute walk without your phone", "Journal each evening about how the day felt"]
        case "Meal Prep Master":
            return ["Plan 5 dinners + lunches for the week", "Write grocery list organized by store section", "Shop & buy everything in one trip", "Batch cook proteins, grains & chop veggies", "Portion into containers & label with dates"]

        // MARK: Productivity Methods (unique per method)
        case "Getting Things Done":
            return ["Do a full brain dump — capture everything on your mind", "Process each item: is it actionable? Delete, defer, or do", "Organize into projects, next actions & waiting-for lists", "Review all lists weekly and update", "Trust the system — stop holding tasks in your head"]
        case "Time Blocking":
            return ["List your top 3 priorities for tomorrow", "Block 90-minute deep work sessions on your calendar", "Assign specific tasks to each time block", "Add buffer blocks for email & unexpected tasks", "Review at end of day: did you follow the blocks?"]
        case "Eat The Frog":
            return ["Identify your hardest or most dreaded task", "Do it first thing in the morning — no excuses", "Set a timer for 25 minutes and just start", "Reward yourself after completing it", "Pick tomorrow's frog before leaving work today"]
        case "Eisenhower Matrix":
            return ["List all your current tasks and to-dos", "Sort each into: Urgent+Important, Important, Urgent, Neither", "Do Urgent+Important tasks immediately", "Schedule Important tasks for this week", "Delegate or delete everything else"]
        case "Kanban":
            return ["Create three columns: To Do, In Progress, Done", "Add all current tasks to the To Do column", "Move only 3 tasks to In Progress at a time", "Move tasks to Done as you complete them", "Review the board daily and add new tasks"]
        case "The Pomodoro Technique":
            return ["Choose one task to focus on", "Set a 25-minute timer and work with zero distractions", "Take a 5-minute break when the timer rings", "After 4 pomodoros, take a 15-30 minute break", "Log how many pomodoros each task took"]
        case "The 1-3-5 Rule":
            return ["Pick 1 big task that will move the needle today", "Pick 3 medium tasks that support your goals", "Pick 5 small tasks (emails, errands, quick fixes)", "Work through them in order: big → medium → small", "End of day: celebrate what you finished"]
        case "Energy Mapping":
            return ["Track your energy levels every 2 hours for 3 days", "Identify your consistent high & low energy windows", "Schedule deep work during your peak energy time", "Move meetings & admin to your low energy slots", "Adjust weekly as your patterns shift"]

        default:
            return ["Define your goal clearly", "Break it into 5 actionable steps", "Set a deadline for each step", "Track progress daily", "Review & celebrate your wins"]
        }
    }

    // MARK: - Template Data

    // Featured
    private var featuredTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "AI Task Breakdown",
                description: "Let AI break any complex goal into actionable subtasks",
                icon: "wand.and.stars",
                color: Color.fdPurple,
                category: "featured",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Weekly Review Ritual",
                description: "Reflect on wins, clear the backlog, and plan ahead",
                icon: "calendar.badge.checkmark",
                color: Color.fdBlue,
                category: "featured",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Morning Power Hour",
                description: "Start every day with intention using this structured routine",
                icon: "sunrise",
                color: Color.fdYellow,
                category: "featured",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Focus Sprint",
                description: "Deep work sessions with AI-optimized break timing",
                icon: "bolt.fill",
                color: Color.fdGreen,
                category: "featured",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Real Estate
    private var realEstateTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Open House Prep",
                description: "Complete checklist from staging to follow-ups",
                icon: "house",
                color: Color.fdAccent,
                category: "Real Estate",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Listing Launch",
                description: "From photos to MLS — launch listings like a pro",
                icon: "megaphone",
                color: Color.fdAccent,
                category: "Real Estate",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Buyer Pipeline",
                description: "Track leads from first contact to closing",
                icon: "person.2",
                color: Color.fdAccentSoft,
                category: "Real Estate",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Transaction Coordinator",
                description: "Every step from offer to close, nothing missed",
                icon: "doc.text.magnifyingglass",
                color: Color.fdAccent,
                category: "Real Estate",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Freelance & Agency
    private var freelanceTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Client Onboarding",
                description: "Smooth handoff from signed contract to kickoff",
                icon: "handshake",
                color: Color.fdBlue,
                category: "Freelance & Agency",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Project Sprint",
                description: "Agile-inspired workflow for client deliverables",
                icon: "arrow.triangle.branch",
                color: Color.fdBlue,
                category: "Freelance & Agency",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Invoice & Follow-up",
                description: "Never miss a payment with automated reminders",
                icon: "dollarsign.circle",
                color: Color.fdGreen,
                category: "Freelance & Agency",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Students
    private var studentTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Semester Planner",
                description: "Map out assignments, exams, and study blocks",
                icon: "book",
                color: Color.fdPurple,
                category: "Students",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Research Paper",
                description: "From thesis to citations — structured writing workflow",
                icon: "doc.text",
                color: Color.fdPurple,
                category: "Students",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Exam Prep Sprint",
                description: "Spaced repetition study plan with energy tracking",
                icon: "brain",
                color: Color.fdPurple,
                category: "Students",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Healthcare
    private var healthcareTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Patient Follow-up",
                description: "Track appointments, notes, and care plans",
                icon: "stethoscope",
                color: Color.fdRed,
                category: "Healthcare",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Shift Handoff",
                description: "Structured handoff checklist between shifts",
                icon: "arrow.left.arrow.right",
                color: Color.fdRed,
                category: "Healthcare",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Continuing Education",
                description: "Track CE credits, courses, and certifications",
                icon: "medal",
                color: Color.fdYellow,
                category: "Healthcare",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Construction & Trades
    private var constructionTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Job Site Checklist",
                description: "Daily safety, materials, and progress tracking",
                icon: "checklist",
                color: Color.fdYellow,
                category: "Construction & Trades",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Estimate & Bid",
                description: "Structured workflow from site visit to proposal",
                icon: "ruler",
                color: Color.fdYellow,
                category: "Construction & Trades",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Content Creators
    private var contentCreatorTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Content Calendar",
                description: "Plan, create, and schedule across all platforms",
                icon: "calendar",
                color: Color.fdGreen,
                category: "Content Creators",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Video Production",
                description: "From script to upload — complete production pipeline",
                icon: "film",
                color: Color.fdGreen,
                category: "Content Creators",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Brand Collaboration",
                description: "Manage sponsor deals from pitch to deliverable",
                icon: "star.circle",
                color: Color.fdGreen,
                category: "Content Creators",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Small Business
    private var smallBusinessTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Business Launch Checklist",
                description: "From registration to first sale — launch with confidence",
                icon: "storefront",
                color: Color.fdAccent,
                category: "Small Business",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Inventory Management",
                description: "Track stock levels, reorders, and supplier timelines",
                icon: "shippingbox",
                color: Color.fdAccent,
                category: "Small Business",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Customer Feedback Loop",
                description: "Collect, analyze, and act on customer feedback",
                icon: "bubble.left.and.bubble.right",
                color: Color.fdAccentSoft,
                category: "Small Business",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Sales & Marketing
    private var salesMarketingTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Product Launch",
                description: "Coordinate messaging, channels, and buzz for launch day",
                icon: "megaphone",
                color: Color.fdPurple,
                category: "Sales & Marketing",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Lead Nurture Sequence",
                description: "Turn cold leads warm with a structured email sequence",
                icon: "envelope.badge",
                color: Color.fdPurple,
                category: "Sales & Marketing",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Campaign Tracker",
                description: "Monitor ad spend, KPIs, and ROI across campaigns",
                icon: "chart.bar",
                color: Color.fdBlue,
                category: "Sales & Marketing",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Software & Engineering
    private var softwareTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Sprint Planning",
                description: "Prioritize, estimate, and assign work for the sprint",
                icon: "chevron.left.forwardslash.chevron.right",
                color: Color.fdBlue,
                category: "Software & Engineering",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Bug Triage",
                description: "Reproduce, prioritize, and assign bugs systematically",
                icon: "ladybug",
                color: Color.fdRed,
                category: "Software & Engineering",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Feature Rollout",
                description: "From spec to production with feature flags and monitoring",
                icon: "flag.checkered",
                color: Color.fdGreen,
                category: "Software & Engineering",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Legal & Compliance
    private var legalTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Contract Review",
                description: "Systematic review of terms, risks, and obligations",
                icon: "doc.text.magnifyingglass",
                color: Color.fdPurple,
                category: "Legal & Compliance",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Compliance Audit",
                description: "Verify regulatory compliance and close gaps",
                icon: "checkmark.shield",
                color: Color.fdPurple,
                category: "Legal & Compliance",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Case File Setup",
                description: "Organize new cases with documents, dates, and strategy",
                icon: "folder.badge.gearshape",
                color: Color.fdBlue,
                category: "Legal & Compliance",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Finance & Accounting
    private var financeTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Monthly Close",
                description: "Reconcile, adjust, and report — close the books cleanly",
                icon: "dollarsign.circle",
                color: Color.fdGreen,
                category: "Finance & Accounting",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Tax Prep Checklist",
                description: "Gather docs, review deductions, and file on time",
                icon: "doc.richtext",
                color: Color.fdGreen,
                category: "Finance & Accounting",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Budget Planning",
                description: "Set targets, track actuals, and plan next period",
                icon: "chart.pie",
                color: Color.fdYellow,
                category: "Finance & Accounting",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Events & Planning
    private var eventsTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Event Planning",
                description: "From concept to thank-you notes — plan any event",
                icon: "party.popper",
                color: Color.fdAccent,
                category: "Events & Planning",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Conference Prep",
                description: "Travel, sessions, and networking all organized",
                icon: "person.3",
                color: Color.fdBlue,
                category: "Events & Planning",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Party Planner",
                description: "Theme, food, music, decorations — nothing forgotten",
                icon: "balloon.2",
                color: Color.fdRed,
                category: "Events & Planning",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Nonprofit & Community
    private var nonprofitTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Fundraising Campaign",
                description: "Set goals, reach donors, and track donations",
                icon: "hands.sparkles",
                color: Color.fdYellow,
                category: "Nonprofit & Community",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Volunteer Coordination",
                description: "Recruit, schedule, and manage volunteers smoothly",
                icon: "person.3.sequence",
                color: Color.fdGreen,
                category: "Nonprofit & Community",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Grant Application",
                description: "Research, write, review & submit on deadline",
                icon: "doc.badge.arrow.up",
                color: Color.fdBlue,
                category: "Nonprofit & Community",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Education & Teaching
    private var educationTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Lesson Plan Builder",
                description: "Objectives, activities, materials & assessment in one flow",
                icon: "text.book.closed",
                color: Color.fdPurple,
                category: "Education & Teaching",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Parent-Teacher Prep",
                description: "Student progress, talking points & follow-up actions",
                icon: "person.2",
                color: Color.fdPurple,
                category: "Education & Teaching",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Classroom Setup",
                description: "Desks, tech, supplies & first-day activities ready to go",
                icon: "desktopcomputer",
                color: Color.fdYellow,
                category: "Education & Teaching",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Life & Personal
    private var personalTemplates: [TemplateItem] {
        [
            TemplateItem(
                name: "Home Renovation",
                description: "Room-by-room planning with budget tracking",
                icon: "house",
                color: Color.fdAccent,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Wedding Planning",
                description: "From save-the-dates to honeymoon, every detail covered",
                icon: "heart",
                color: Color.fdRed,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Move & Relocate",
                description: "The ultimate moving checklist — packing to utilities",
                icon: "shippingbox",
                color: Color.fdBlue,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Travel Planner",
                description: "Itinerary, packing, bookings, and day-by-day schedule",
                icon: "airplane",
                color: Color.fdBlue,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Fitness Journey",
                description: "Workout plans, meal prep, and progress tracking",
                icon: "figure.run",
                color: Color.fdGreen,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Side Hustle Launch",
                description: "Turn your idea into income with this startup template",
                icon: "lightbulb",
                color: Color.fdYellow,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Digital Detox Week",
                description: "Structured plan to reset your relationship with tech",
                icon: "phone.down",
                color: Color.fdPurple,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Meal Prep Master",
                description: "Weekly meal planning, grocery lists, and prep schedules",
                icon: "fork.knife",
                color: Color.fdAccent,
                category: "Life & Personal",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }

    // Productivity Methods
    private var productivityMethods: [TemplateItem] {
        [
            TemplateItem(
                name: "Getting Things Done",
                description: "Clear your mind and embrace calm productivity with GTD.",
                icon: "target",
                color: Color.fdAccent,
                category: "Productivity",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Time Blocking",
                description: "Regain control of your time and focus with time blocking.",
                icon: "clock.arrow.circlepath",
                color: Color.fdBlue,
                category: "Productivity",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Eat The Frog",
                description: "Beat procrastination and ensure you're doing your hardest tasks first.",
                icon: "hare",
                color: Color.fdGreen,
                category: "Productivity",
                projects: 1, labels: 1, filters: 1
            ),
            TemplateItem(
                name: "Eisenhower Matrix",
                description: "Make time for what's truly important, not just urgent.",
                icon: "square.grid.2x2",
                color: Color.fdPurple,
                category: "Productivity",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Kanban",
                description: "Move your project tasks through a visual pipeline.",
                icon: "rectangle.split.3x1",
                color: Color.fdYellow,
                category: "Productivity",
                projects: 1, labels: 1, filters: 2
            ),
            TemplateItem(
                name: "The Pomodoro Technique",
                description: "Avoid procrastination and regain focus with timed sessions.",
                icon: "timer",
                color: Color.fdRed,
                category: "Productivity",
                projects: 1, labels: 5, filters: 2
            ),
            TemplateItem(
                name: "The 1-3-5 Rule",
                description: "1 big thing, 3 medium things, 5 small things daily",
                icon: "list.number",
                color: Color.fdAccent,
                category: "Productivity",
                projects: 1, labels: 2, filters: 1
            ),
            TemplateItem(
                name: "Energy Mapping",
                description: "FlowDay exclusive — schedule tasks to match your energy curve",
                icon: "waveform.path.ecg",
                color: Color.fdAccent,
                category: "Productivity",
                projects: 1, labels: 2, filters: 1
            ),
        ]
    }
}

// MARK: - Template Tab Enum

enum TemplateTab: CaseIterable {
    case featured, industries, personal, productivity, aiGenerate

    var title: String {
        switch self {
        case .featured: return "Featured"
        case .industries: return "Industries"
        case .personal: return "Life & Personal"
        case .productivity: return "Methods"
        case .aiGenerate: return "AI Generate"
        }
    }

    var icon: String {
        switch self {
        case .featured: return "sparkles"
        case .industries: return "building.2"
        case .personal: return "heart"
        case .productivity: return "brain.head.profile"
        case .aiGenerate: return "wand.and.stars"
        }
    }
}

// MARK: - Template Item Struct

struct TemplateItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let category: String
    let projects: Int
    let labels: Int
    let filters: Int
}
