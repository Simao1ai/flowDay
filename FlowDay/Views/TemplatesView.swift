// TemplatesView.swift
// FlowDay
//
// Template picker — Featured, Industries, Life & Personal, Productivity
// Methods, and AI Generator tabs. Data/logic live in extension files:
//   • TemplatesView+Types.swift   — TemplateTab + TemplateItem
//   • TemplatesView+Catalog.swift — curated template lists per industry
//   • TemplatesView+Apply.swift   — "Use template" → project + starter tasks
//   • TemplatesView+AI.swift      — Claude-generated custom templates

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State var selectedTab: TemplateTab = .featured
    @State var searchText = ""
    @State var aiPrompt = ""
    @State var isGeneratingTemplate = false
    @State var generationError: String?
    @State var appliedTemplateName: String?
    @State var showTemplateApplied = false

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
            .overlay { appliedToast }
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
        Button {
            Haptics.pick()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
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
        case .featured:     featuredContent
        case .industries:   industriesContent
        case .personal:     personalContent
        case .productivity: productivityContent
        case .aiGenerate:   aiGenerateContent
        }
    }

    // MARK: - Featured Tab

    private var featuredContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            industrySection(emoji: "🏠", title: "Real Estate", icon: "building.columns", templates: realEstateTemplates)
            industrySection(emoji: "💼", title: "Freelance & Agency", icon: "laptopcomputer", templates: freelanceTemplates)
            industrySection(emoji: "🏪", title: "Small Business", icon: "storefront", templates: smallBusinessTemplates)
            industrySection(emoji: "📣", title: "Sales & Marketing", icon: "megaphone", templates: salesMarketingTemplates)
            industrySection(emoji: "💻", title: "Software & Engineering", icon: "chevron.left.forwardslash.chevron.right", templates: softwareTemplates)
            industrySection(emoji: "🎓", title: "Students", icon: "graduationcap", templates: studentTemplates)
            industrySection(emoji: "🏥", title: "Healthcare", icon: "cross.case", templates: healthcareTemplates)
            industrySection(emoji: "⚖️", title: "Legal & Compliance", icon: "building.columns", templates: legalTemplates)
            industrySection(emoji: "💰", title: "Finance & Accounting", icon: "dollarsign.circle", templates: financeTemplates)
            industrySection(emoji: "📚", title: "Education & Teaching", icon: "book", templates: educationTemplates)
            industrySection(emoji: "🏗️", title: "Construction & Trades", icon: "hammer", templates: constructionTemplates)
            industrySection(emoji: "📱", title: "Content Creators", icon: "video", templates: contentCreatorTemplates)
            industrySection(emoji: "🎉", title: "Events & Planning", icon: "party.popper", templates: eventsTemplates)
            industrySection(emoji: "🤝", title: "Nonprofit & Community", icon: "heart.circle", templates: nonprofitTemplates)
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
                        .background(Circle().fill(template.color.opacity(0.1)))

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

            Button { applyTemplate(template) } label: {
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

    // MARK: - Life & Personal

    private var personalContent: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(personalTemplates) { tmpl in
                standardTemplateCard(template: tmpl)
            }
        }
    }

    // MARK: - Productivity Methods

    private var productivityContent: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(productivityMethods) { method in
                methodCard(method: method)
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

            Button { applyTemplate(method) } label: {
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
                    Haptics.tock()
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
                            icon: "waveform", color: Color.fdPurple, category: "AI Generated",
                            projects: 1, labels: 2, filters: 1
                        )
                    )
                    aiGeneratedCard(
                        template: TemplateItem(
                            name: "App Launch Checklist",
                            description: "Product roadmap, beta testing, launch day coordination",
                            icon: "square.stack.3d.up", color: Color.fdBlue, category: "AI Generated",
                            projects: 1, labels: 2, filters: 1
                        )
                    )
                }
            }
        }
    }

    private func aiGeneratedCard(template: TemplateItem) -> some View {
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
                        .background(Circle().fill(template.color.opacity(0.1)))

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

            Button { applyTemplate(template) } label: {
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

    // MARK: - Applied Toast

    @ViewBuilder
    private var appliedToast: some View {
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
}
