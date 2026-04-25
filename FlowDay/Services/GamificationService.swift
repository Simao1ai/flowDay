// GamificationService.swift
// FlowDay — XP, levels, streaks, and achievements

import Foundation
import Observation

// MARK: - Achievement

enum Achievement: String, CaseIterable, Codable {
    case firstFlow        = "first_flow"
    case streakStarter    = "streak_starter"
    case weekWarrior      = "week_warrior"
    case monthMaster      = "month_master"
    case centuryClub      = "century_club"
    case focusChampion    = "focus_champion"
    case aiExplorer       = "ai_explorer"
    case templatePro      = "template_pro"
    case energyAware      = "energy_aware"

    var title: String {
        switch self {
        case .firstFlow:     return "First Flow"
        case .streakStarter: return "Streak Starter"
        case .weekWarrior:   return "Week Warrior"
        case .monthMaster:   return "Month Master"
        case .centuryClub:   return "Century Club"
        case .focusChampion: return "Focus Champion"
        case .aiExplorer:    return "AI Explorer"
        case .templatePro:   return "Template Pro"
        case .energyAware:   return "Energy Aware"
        }
    }

    var subtitle: String {
        switch self {
        case .firstFlow:     return "Complete your first task"
        case .streakStarter: return "3-day streak"
        case .weekWarrior:   return "7-day streak"
        case .monthMaster:   return "30-day streak"
        case .centuryClub:   return "Complete 100 tasks"
        case .focusChampion: return "10 focus sessions"
        case .aiExplorer:    return "Use AI 10 times"
        case .templatePro:   return "Use 5 templates"
        case .energyAware:   return "Log energy 7 days"
        }
    }

    var icon: String {
        switch self {
        case .firstFlow:     return "checkmark.seal.fill"
        case .streakStarter: return "flame"
        case .weekWarrior:   return "flame.fill"
        case .monthMaster:   return "crown.fill"
        case .centuryClub:   return "100.circle.fill"
        case .focusChampion: return "timer"
        case .aiExplorer:    return "sparkles"
        case .templatePro:   return "doc.badge.gearshape"
        case .energyAware:   return "bolt.heart.fill"
        }
    }

    var xpReward: Int { 50 }
}

// MARK: - XP Event

enum XPEvent {
    case taskCompleted(priority: Int)
    case habitCompleted
    case focusSessionCompleted
    case allDailyTasksCompleted
    case aiPlanUsed
    case templateUsed
    case energyLogged

    var xp: Int {
        switch self {
        case .taskCompleted(let p):
            switch p {
            case 1: return 20
            case 2: return 15
            default: return 10
            }
        case .habitCompleted:             return 15
        case .focusSessionCompleted:      return 25
        case .allDailyTasksCompleted:     return 50
        case .aiPlanUsed:                 return 5
        case .templateUsed:               return 5
        case .energyLogged:               return 5
        }
    }
}

// MARK: - GamificationService

@Observable @MainActor
final class GamificationService {

    static let shared = GamificationService()

    // Persisted counters
    private(set) var totalXP: Int = 0
    private(set) var currentStreak: Int = 0
    private(set) var unlockedAchievements: [Achievement] = []

    // In-session toast
    private(set) var pendingToast: ToastItem? = nil

    struct ToastItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let xp: Int
    }

    // UserDefaults keys
    private enum Key {
        static let totalXP             = "gam_total_xp"
        static let currentStreak       = "gam_streak"
        static let streakLastDate      = "gam_streak_last_date"
        static let unlockedAchievements = "gam_achievements"
        static let totalTasksCompleted  = "gam_tasks_completed"
        static let totalFocusSessions   = "gam_focus_sessions"
        static let totalAIUses          = "gam_ai_uses"
        static let totalTemplateUses    = "gam_template_uses"
        static let totalEnergyLogs      = "gam_energy_logs"
    }

    // Derived
    var level: Int { max(1, totalXP / 100 + 1) }
    var xpInCurrentLevel: Int { totalXP % 100 }
    var xpProgress: Double { Double(xpInCurrentLevel) / 100.0 }

    private var totalTasksCompleted: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalTasksCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalTasksCompleted) }
    }
    private var totalFocusSessions: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalFocusSessions) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalFocusSessions) }
    }
    private var totalAIUses: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalAIUses) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalAIUses) }
    }
    private var totalTemplateUses: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalTemplateUses) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalTemplateUses) }
    }
    private var totalEnergyLogs: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalEnergyLogs) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalEnergyLogs) }
    }

    private init() { load() }

    // MARK: - Record XP

    func record(_ event: XPEvent) {
        let gained = event.xp
        totalXP += gained
        UserDefaults.standard.set(totalXP, forKey: Key.totalXP)

        switch event {
        case .taskCompleted:
            totalTasksCompleted += 1
        case .focusSessionCompleted:
            totalFocusSessions += 1
        case .aiPlanUsed:
            totalAIUses += 1
        case .templateUsed:
            totalTemplateUses += 1
        case .energyLogged:
            totalEnergyLogs += 1
        default:
            break
        }

        checkAchievements()
        showToast(for: event, xp: gained)
    }

    // MARK: - Streak

    func checkAndUpdateStreak() {
        let today = Calendar.current.startOfDay(for: .now)
        let stored = UserDefaults.standard.double(forKey: Key.streakLastDate)
        let lastDate = stored > 0 ? Calendar.current.startOfDay(for: Date(timeIntervalSince1970: stored)) : nil

        if let last = lastDate {
            let diff = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
            if diff == 0 {
                return // already counted today
            } else if diff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1 // streak broken
            }
        } else {
            currentStreak = 1
        }

        UserDefaults.standard.set(currentStreak, forKey: Key.currentStreak)
        UserDefaults.standard.set(today.timeIntervalSince1970, forKey: Key.streakLastDate)
        checkAchievements()
    }

    // MARK: - Toast

    func dismissToast() {
        pendingToast = nil
    }

    // MARK: - Private

    private func load() {
        totalXP = UserDefaults.standard.integer(forKey: Key.totalXP)
        currentStreak = UserDefaults.standard.integer(forKey: Key.currentStreak)

        if let data = UserDefaults.standard.data(forKey: Key.unlockedAchievements),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            unlockedAchievements = decoded
        }
    }

    private func checkAchievements() {
        var newlyUnlocked: [Achievement] = []

        func unlock(_ a: Achievement) {
            guard !unlockedAchievements.contains(a) else { return }
            unlockedAchievements.append(a)
            newlyUnlocked.append(a)
            totalXP += a.xpReward
            UserDefaults.standard.set(totalXP, forKey: Key.totalXP)
        }

        if totalTasksCompleted >= 1  { unlock(.firstFlow) }
        if currentStreak >= 3        { unlock(.streakStarter) }
        if currentStreak >= 7        { unlock(.weekWarrior) }
        if currentStreak >= 30       { unlock(.monthMaster) }
        if totalTasksCompleted >= 100 { unlock(.centuryClub) }
        if totalFocusSessions >= 10  { unlock(.focusChampion) }
        if totalAIUses >= 10         { unlock(.aiExplorer) }
        if totalTemplateUses >= 5    { unlock(.templatePro) }
        if totalEnergyLogs >= 7      { unlock(.energyAware) }

        if let data = try? JSONEncoder().encode(unlockedAchievements) {
            UserDefaults.standard.set(data, forKey: Key.unlockedAchievements)
        }

        // Show toast for first unlocked achievement this batch
        if let first = newlyUnlocked.first {
            pendingToast = ToastItem(
                title: "Achievement Unlocked!",
                subtitle: first.title,
                icon: first.icon,
                xp: first.xpReward
            )
        }
    }

    private func showToast(for event: XPEvent, xp: Int) {
        guard pendingToast == nil else { return }
        let label: String
        switch event {
        case .taskCompleted:             label = "Task completed"
        case .habitCompleted:            label = "Habit done!"
        case .focusSessionCompleted:     label = "Focus session complete"
        case .allDailyTasksCompleted:    label = "All tasks done! Bonus XP!"
        case .aiPlanUsed:                label = "AI plan used"
        case .templateUsed:              label = "Template used"
        case .energyLogged:              label = "Energy logged"
        }
        pendingToast = ToastItem(title: label, subtitle: "+\(xp) XP", icon: "star.fill", xp: xp)
    }
}
