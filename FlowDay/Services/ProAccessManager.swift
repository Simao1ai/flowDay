// ProAccessManager.swift
// FlowDay — Tracks free-tier AI usage and gates Pro features

import Foundation

@Observable @MainActor
final class ProAccessManager {

    static let shared = ProAccessManager()

    private let callsKey   = "pro_daily_ai_calls"
    private let dateKey    = "pro_ai_calls_date"
    let freeAILimit        = 5

    // Stored observable property — drives view updates
    var dailyAICallsUsed: Int = 0

    private init() { loadAndResetIfNewDay() }

    // MARK: - Computed

    var isPro: Bool { SubscriptionManager.shared.status != .free }

    var canUseAI: Bool { isPro || dailyAICallsUsed < freeAILimit }

    var aiCallsRemaining: Int { isPro ? Int.max : max(0, freeAILimit - dailyAICallsUsed) }

    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        SubscriptionManager.shared.canAccess(feature)
    }

    // MARK: - Recording

    func recordAICall() {
        loadAndResetIfNewDay()
        dailyAICallsUsed += 1
        UserDefaults.standard.set(dailyAICallsUsed, forKey: callsKey)
    }

    // MARK: - Daily Reset

    private func loadAndResetIfNewDay() {
        let today   = Calendar.current.startOfDay(for: .now)
        let stored  = UserDefaults.standard.double(forKey: dateKey)
        let lastDay = stored > 0 ? Date(timeIntervalSince1970: stored) : nil

        if lastDay == nil || !Calendar.current.isDate(lastDay!, inSameDayAs: today) {
            dailyAICallsUsed = 0
            UserDefaults.standard.set(0, forKey: callsKey)
            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: dateKey)
        } else {
            dailyAICallsUsed = UserDefaults.standard.integer(forKey: callsKey)
        }
    }
}
