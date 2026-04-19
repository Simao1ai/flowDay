// TemplatesView+Catalog.swift
// FlowDay
//
// Static catalog of curated template definitions. Pulled out of the main
// TemplatesView file so the rendering logic doesn't drown in data.

import SwiftUI

extension TemplatesView {

    var featuredTemplates: [TemplateItem] {
        [
            TemplateItem(name: "AI Task Breakdown",
                         description: "Let AI break any complex goal into actionable subtasks",
                         icon: "wand.and.stars", color: Color.fdPurple, category: "featured",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Weekly Review Ritual",
                         description: "Reflect on wins, clear the backlog, and plan ahead",
                         icon: "calendar.badge.checkmark", color: Color.fdBlue, category: "featured",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Morning Power Hour",
                         description: "Start every day with intention using this structured routine",
                         icon: "sunrise", color: Color.fdYellow, category: "featured",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Focus Sprint",
                         description: "Deep work sessions with AI-optimized break timing",
                         icon: "bolt.fill", color: Color.fdGreen, category: "featured",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var realEstateTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Open House Prep",
                         description: "Complete checklist from staging to follow-ups",
                         icon: "house", color: Color.fdAccent, category: "Real Estate",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Listing Launch",
                         description: "From photos to MLS — launch listings like a pro",
                         icon: "megaphone", color: Color.fdAccent, category: "Real Estate",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Buyer Pipeline",
                         description: "Track leads from first contact to closing",
                         icon: "person.2", color: Color.fdAccentSoft, category: "Real Estate",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Transaction Coordinator",
                         description: "Every step from offer to close, nothing missed",
                         icon: "doc.text.magnifyingglass", color: Color.fdAccent, category: "Real Estate",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var freelanceTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Client Onboarding",
                         description: "Smooth handoff from signed contract to kickoff",
                         icon: "handshake", color: Color.fdBlue, category: "Freelance & Agency",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Project Sprint",
                         description: "Agile-inspired workflow for client deliverables",
                         icon: "arrow.triangle.branch", color: Color.fdBlue, category: "Freelance & Agency",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Invoice & Follow-up",
                         description: "Never miss a payment with automated reminders",
                         icon: "dollarsign.circle", color: Color.fdGreen, category: "Freelance & Agency",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var studentTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Semester Planner",
                         description: "Map out assignments, exams, and study blocks",
                         icon: "book", color: Color.fdPurple, category: "Students",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Research Paper",
                         description: "From thesis to citations — structured writing workflow",
                         icon: "doc.text", color: Color.fdPurple, category: "Students",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Exam Prep Sprint",
                         description: "Spaced repetition study plan with energy tracking",
                         icon: "brain", color: Color.fdPurple, category: "Students",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var healthcareTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Patient Follow-up",
                         description: "Track appointments, notes, and care plans",
                         icon: "stethoscope", color: Color.fdRed, category: "Healthcare",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Shift Handoff",
                         description: "Structured handoff checklist between shifts",
                         icon: "arrow.left.arrow.right", color: Color.fdRed, category: "Healthcare",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Continuing Education",
                         description: "Track CE credits, courses, and certifications",
                         icon: "medal", color: Color.fdYellow, category: "Healthcare",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var constructionTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Job Site Checklist",
                         description: "Daily safety, materials, and progress tracking",
                         icon: "checklist", color: Color.fdYellow, category: "Construction & Trades",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Estimate & Bid",
                         description: "Structured workflow from site visit to proposal",
                         icon: "ruler", color: Color.fdYellow, category: "Construction & Trades",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var contentCreatorTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Content Calendar",
                         description: "Plan, create, and schedule across all platforms",
                         icon: "calendar", color: Color.fdGreen, category: "Content Creators",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Video Production",
                         description: "From script to upload — complete production pipeline",
                         icon: "film", color: Color.fdGreen, category: "Content Creators",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Brand Collaboration",
                         description: "Manage sponsor deals from pitch to deliverable",
                         icon: "star.circle", color: Color.fdGreen, category: "Content Creators",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var smallBusinessTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Business Launch Checklist",
                         description: "From registration to first sale — launch with confidence",
                         icon: "storefront", color: Color.fdAccent, category: "Small Business",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Inventory Management",
                         description: "Track stock levels, reorders, and supplier timelines",
                         icon: "shippingbox", color: Color.fdAccent, category: "Small Business",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Customer Feedback Loop",
                         description: "Collect, analyze, and act on customer feedback",
                         icon: "bubble.left.and.bubble.right", color: Color.fdAccentSoft, category: "Small Business",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var salesMarketingTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Product Launch",
                         description: "Coordinate messaging, channels, and buzz for launch day",
                         icon: "megaphone", color: Color.fdPurple, category: "Sales & Marketing",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Lead Nurture Sequence",
                         description: "Turn cold leads warm with a structured email sequence",
                         icon: "envelope.badge", color: Color.fdPurple, category: "Sales & Marketing",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Campaign Tracker",
                         description: "Monitor ad spend, KPIs, and ROI across campaigns",
                         icon: "chart.bar", color: Color.fdBlue, category: "Sales & Marketing",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var softwareTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Sprint Planning",
                         description: "Prioritize, estimate, and assign work for the sprint",
                         icon: "chevron.left.forwardslash.chevron.right", color: Color.fdBlue, category: "Software & Engineering",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Bug Triage",
                         description: "Reproduce, prioritize, and assign bugs systematically",
                         icon: "ladybug", color: Color.fdRed, category: "Software & Engineering",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Feature Rollout",
                         description: "From spec to production with feature flags and monitoring",
                         icon: "flag.checkered", color: Color.fdGreen, category: "Software & Engineering",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var legalTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Contract Review",
                         description: "Systematic review of terms, risks, and obligations",
                         icon: "doc.text.magnifyingglass", color: Color.fdPurple, category: "Legal & Compliance",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Compliance Audit",
                         description: "Verify regulatory compliance and close gaps",
                         icon: "checkmark.shield", color: Color.fdPurple, category: "Legal & Compliance",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Case File Setup",
                         description: "Organize new cases with documents, dates, and strategy",
                         icon: "folder.badge.gearshape", color: Color.fdBlue, category: "Legal & Compliance",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var financeTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Monthly Close",
                         description: "Reconcile, adjust, and report — close the books cleanly",
                         icon: "dollarsign.circle", color: Color.fdGreen, category: "Finance & Accounting",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Tax Prep Checklist",
                         description: "Gather docs, review deductions, and file on time",
                         icon: "doc.richtext", color: Color.fdGreen, category: "Finance & Accounting",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Budget Planning",
                         description: "Set targets, track actuals, and plan next period",
                         icon: "chart.pie", color: Color.fdYellow, category: "Finance & Accounting",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var eventsTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Event Planning",
                         description: "From concept to thank-you notes — plan any event",
                         icon: "party.popper", color: Color.fdAccent, category: "Events & Planning",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Conference Prep",
                         description: "Travel, sessions, and networking all organized",
                         icon: "person.3", color: Color.fdBlue, category: "Events & Planning",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Party Planner",
                         description: "Theme, food, music, decorations — nothing forgotten",
                         icon: "balloon.2", color: Color.fdRed, category: "Events & Planning",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var nonprofitTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Fundraising Campaign",
                         description: "Set goals, reach donors, and track donations",
                         icon: "hands.sparkles", color: Color.fdYellow, category: "Nonprofit & Community",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Volunteer Coordination",
                         description: "Recruit, schedule, and manage volunteers smoothly",
                         icon: "person.3.sequence", color: Color.fdGreen, category: "Nonprofit & Community",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Grant Application",
                         description: "Research, write, review & submit on deadline",
                         icon: "doc.badge.arrow.up", color: Color.fdBlue, category: "Nonprofit & Community",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var educationTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Lesson Plan Builder",
                         description: "Objectives, activities, materials & assessment in one flow",
                         icon: "text.book.closed", color: Color.fdPurple, category: "Education & Teaching",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Parent-Teacher Prep",
                         description: "Student progress, talking points & follow-up actions",
                         icon: "person.2", color: Color.fdPurple, category: "Education & Teaching",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Classroom Setup",
                         description: "Desks, tech, supplies & first-day activities ready to go",
                         icon: "desktopcomputer", color: Color.fdYellow, category: "Education & Teaching",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var personalTemplates: [TemplateItem] {
        [
            TemplateItem(name: "Home Renovation",
                         description: "Room-by-room planning with budget tracking",
                         icon: "house", color: Color.fdAccent, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Wedding Planning",
                         description: "From save-the-dates to honeymoon, every detail covered",
                         icon: "heart", color: Color.fdRed, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Move & Relocate",
                         description: "The ultimate moving checklist — packing to utilities",
                         icon: "shippingbox", color: Color.fdBlue, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Travel Planner",
                         description: "Itinerary, packing, bookings, and day-by-day schedule",
                         icon: "airplane", color: Color.fdBlue, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Fitness Journey",
                         description: "Workout plans, meal prep, and progress tracking",
                         icon: "figure.run", color: Color.fdGreen, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Side Hustle Launch",
                         description: "Turn your idea into income with this startup template",
                         icon: "lightbulb", color: Color.fdYellow, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Digital Detox Week",
                         description: "Structured plan to reset your relationship with tech",
                         icon: "phone.down", color: Color.fdPurple, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Meal Prep Master",
                         description: "Weekly meal planning, grocery lists, and prep schedules",
                         icon: "fork.knife", color: Color.fdAccent, category: "Life & Personal",
                         projects: 1, labels: 2, filters: 1),
        ]
    }

    var productivityMethods: [TemplateItem] {
        [
            TemplateItem(name: "Getting Things Done",
                         description: "Clear your mind and embrace calm productivity with GTD.",
                         icon: "target", color: Color.fdAccent, category: "Productivity",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Time Blocking",
                         description: "Regain control of your time and focus with time blocking.",
                         icon: "clock.arrow.circlepath", color: Color.fdBlue, category: "Productivity",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Eat The Frog",
                         description: "Beat procrastination and ensure you're doing your hardest tasks first.",
                         icon: "hare", color: Color.fdGreen, category: "Productivity",
                         projects: 1, labels: 1, filters: 1),
            TemplateItem(name: "Eisenhower Matrix",
                         description: "Make time for what's truly important, not just urgent.",
                         icon: "square.grid.2x2", color: Color.fdPurple, category: "Productivity",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Kanban",
                         description: "Move your project tasks through a visual pipeline.",
                         icon: "rectangle.split.3x1", color: Color.fdYellow, category: "Productivity",
                         projects: 1, labels: 1, filters: 2),
            TemplateItem(name: "The Pomodoro Technique",
                         description: "Avoid procrastination and regain focus with timed sessions.",
                         icon: "timer", color: Color.fdRed, category: "Productivity",
                         projects: 1, labels: 5, filters: 2),
            TemplateItem(name: "The 1-3-5 Rule",
                         description: "1 big thing, 3 medium things, 5 small things daily",
                         icon: "list.number", color: Color.fdAccent, category: "Productivity",
                         projects: 1, labels: 2, filters: 1),
            TemplateItem(name: "Energy Mapping",
                         description: "FlowDay exclusive — schedule tasks to match your energy curve",
                         icon: "waveform.path.ecg", color: Color.fdAccent, category: "Productivity",
                         projects: 1, labels: 2, filters: 1),
        ]
    }
}
