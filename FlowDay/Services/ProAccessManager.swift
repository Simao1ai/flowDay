// ProAccessManager.swift
// FlowDay
//
// Single source of truth for Pro feature gating and daily AI usage tracking.
// StoreKit purchasing lives in SubscriptionManager; this class delegates isPro
// to it and adds the per-feature gate logic used throughout the app.

import Foundation
import Observation

// MARK: - Pro Features

enum ProFeature: String, CaseIterable {
    case unlimitedAI
    case emailToTask
    case ramble
    case focusTimerLinked
    case premiumTemplates
    case attachments
    case kanbanBoard
    case weekView
    case smartFilters
    case projectSections
    case copyLink

    var displayName: String {
        switch self {
        case .unlimitedAI:       return "Unlimited AI"
        case .emailToTask:       return "Email to Task"
        case .ramble:            return "Voice Ramble"
        case .focusTimerLinked:  return "Linked Focus Timer"
        case .premiumTemplates:  return "Premium Templates"
        case .attachments:       return "File Attachments"
        case .kanbanBoard:       return "Kanban Board"
        case .weekView:          return "Week View"
        case .smartFilters:      return "Smart Filters"
        case .projectSections:   return "Project Sections"
        case .copyLink:          return "Copy Link"
        }
    }

    var benefitDescription: String {
        switch self {
        case .unlimitedAI:       return "Chat, plan, and create tasks without daily limits"
        case .emailToTask:       return "Auto-scan your inbox and capture action items"
        case .ramble:            return "Dictate multiple tasks hands-free"
        case .focusTimerLinked:  return "Link focus sessions directly to tasks"
        case .premiumTemplates:  return "Access curated project starter kits"
        case .attachments:       return "Add files and photos to any task"
        case .kanbanBoard:       return "View your tasks in a drag-and-drop board"
        case .weekView:          return "Plan and review your entire week at a glance"
        case .smartFilters:      return "Create custom views to filter your tasks"
        case .projectSections:   return "Organize projects into phases or columns"
        case .copyLink:          return "Share individual task links with others"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedAI:       return "sparkles"
        case .emailToTask:       return "envelope.badge"
        case .ramble:            return "mic.fill"
        case .focusTimerLinked:  return "timer"
        case .premiumTemplates:  return "doc.richtext"
        case .attachments:       return "paperclip"
        case .kanbanBoard:       return "rectangle.split.3x1"
        case .weekView:          return "calendar.badge.clock"
        case .smartFilters:      return "line.3.horizontal.decrease.circle"
        case .projectSections:   return "square.stack.3d.up"
        case .copyLink:          return "link"
        }
    }
}

// MARK: - ProAccessManager

@Observable @MainActor
final class ProAccessManager {
    static let shared = ProAccessManager()

    // MARK: - Pro Status (delegates to StoreKit manager)

    var isPro: Bool {
        SubscriptionManager.shared.status == .pro || SubscriptionManager.shared.status == .proTrial
    }

    // MARK: - Daily AI Usage

    private(set) var dailyAICallsUsed: Int = 0
    let dailyAICallLimit: Int = 5

    var canUseAI: Bool { isPro || dailyAICallsUsed < dailyAICallLimit }

    var remainingAICalls: Int {
        isPro ? Int.max : max(0, dailyAICallLimit - dailyAICallsUsed)
    }

    private var lastResetDate: Date?

    private let usedKey  = "pro_daily_ai_used"
    private let dateKey  = "pro_daily_ai_reset"

    // MARK: - Init

    private init() {
        loadUsage()
        checkAndResetDaily()
    }

    // MARK: - Feature Access

    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        isPro
    }

    // MARK: - AI Usage

    func incrementAIUsage() {
        checkAndResetDaily()
        dailyAICallsUsed += 1
        saveUsage()
    }

    func checkAndResetDaily() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let last = lastResetDate, calendar.isDate(last, inSameDayAs: today) {
            return
        }

        dailyAICallsUsed = 0
        lastResetDate = today
        saveUsage()
    }

    // MARK: - Persistence

    private func saveUsage() {
        UserDefaults.standard.set(dailyAICallsUsed, forKey: usedKey)
        if let date = lastResetDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: dateKey)
        }
    }

    private func loadUsage() {
        dailyAICallsUsed = UserDefaults.standard.integer(forKey: usedKey)
        let ts = UserDefaults.standard.double(forKey: dateKey)
        if ts > 0 { lastResetDate = Date(timeIntervalSince1970: ts) }
    }
}
