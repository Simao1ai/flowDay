// SubscriptionManager.swift
// FlowDay
//
// StoreKit 2 subscription manager with freemium feature gating.
// Handles product loading, purchasing, and daily usage tracking.

import Foundation
import StoreKit
import Observation

// MARK: - Subscription Types

enum SubscriptionStatus: String {
    case free
    case pro
    case proTrial
}

enum ProFeature: String, CaseIterable {
    // Legacy (kept for backward compatibility)
    case unlimitedProjects
    case aiPlanning
    case aiChat
    case customThemes
    case prioritySupport
    case advancedAnalytics

    // New Pro-only features
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

    /// Free tier daily limit for legacy usage tracking; new features are fully gated
    var freeLimit: Int? {
        switch self {
        case .unlimitedProjects: return 5
        case .aiPlanning:        return 3
        case .aiChat:            return 10
        default:                 return nil
        }
    }
}

// MARK: - SubscriptionManager

@Observable @MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // Product IDs
    static let monthlyProductID = "io.flowday.pro.monthly"
    static let yearlyProductID = "io.flowday.pro.yearly"

    // State
    var status: SubscriptionStatus = .free
    var products: [Product] = []
    var monthlyProduct: Product?
    var yearlyProduct: Product?
    var isLoading: Bool = false
    var errorMessage: String?

    // Usage tracking
    private var dailyUsage: [String: Int] = [:]
    private var lastUsageResetDate: Date?

    // nonisolated(unsafe) allows deinit (which is always nonisolated) to cancel
    // the background transaction-listener task without a main-actor hop.
    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    private init() {
        loadDailyUsage()
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Feature Access

    /// Check if user can access a given pro feature
    func canAccess(_ feature: ProFeature) -> Bool {
        if status == .pro || status == .proTrial {
            return true
        }

        // Free tier — new features are fully Pro-only
        switch feature {
        case .unlimitedAI, .emailToTask, .ramble, .focusTimerLinked,
             .premiumTemplates, .attachments, .kanbanBoard, .weekView,
             .smartFilters, .projectSections, .copyLink,
             .customThemes, .prioritySupport, .advancedAnalytics:
            return false
        case .unlimitedProjects, .aiPlanning, .aiChat:
            return true // accessible with daily limits
        }
    }

    /// Check if user has remaining daily usage for a feature
    func hasRemainingUsage(_ feature: ProFeature) -> Bool {
        if status == .pro || status == .proTrial {
            return true
        }

        guard let limit = feature.freeLimit else {
            return false
        }

        resetDailyUsageIfNeeded()
        let currentUsage = dailyUsage[feature.rawValue] ?? 0
        return currentUsage < limit
    }

    /// Increment usage counter for a feature
    func incrementUsage(_ feature: ProFeature) {
        resetDailyUsageIfNeeded()
        let current = dailyUsage[feature.rawValue] ?? 0
        dailyUsage[feature.rawValue] = current + 1
        saveDailyUsage()
    }

    /// Get remaining uses for a feature
    func remainingUses(_ feature: ProFeature) -> Int {
        if status == .pro || status == .proTrial {
            return Int.max
        }

        guard let limit = feature.freeLimit else {
            return 0
        }

        resetDailyUsageIfNeeded()
        let currentUsage = dailyUsage[feature.rawValue] ?? 0
        return max(0, limit - currentUsage)
    }

    // MARK: - StoreKit 2 Methods

    /// Load available products from the App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs: Set<String> = [
                Self.monthlyProductID,
                Self.yearlyProductID
            ]

            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }

            monthlyProduct = products.first { $0.id == Self.monthlyProductID }
            yearlyProduct = products.first { $0.id == Self.yearlyProductID }

            #if DEBUG
            print("[SubscriptionManager] Loaded \(products.count) products")
            #endif
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            #if DEBUG
            print("[SubscriptionManager] Error loading products: \(error)")
            #endif
        }
    }

    /// Purchase a subscription product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkSubscriptionStatus()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }

    /// Check current subscription status
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.monthlyProductID ||
                    transaction.productID == Self.yearlyProductID {
                    hasActiveSubscription = true
                }
            }
        }

        await MainActor.run {
            status = hasActiveSubscription ? .pro : .free
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.checkSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Daily Usage Tracking

    private func resetDailyUsageIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lastReset = lastUsageResetDate {
            if !calendar.isDate(lastReset, inSameDayAs: today) {
                dailyUsage = [:]
                lastUsageResetDate = today
                saveDailyUsage()
            }
        } else {
            lastUsageResetDate = today
        }
    }

    private func saveDailyUsage() {
        UserDefaults.standard.set(dailyUsage, forKey: "fd_daily_usage")
        if let date = lastUsageResetDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "fd_usage_reset_date")
        }
    }

    private func loadDailyUsage() {
        dailyUsage = (UserDefaults.standard.dictionary(forKey: "fd_daily_usage") as? [String: Int]) ?? [:]
        let timestamp = UserDefaults.standard.double(forKey: "fd_usage_reset_date")
        if timestamp > 0 {
            lastUsageResetDate = Date(timeIntervalSince1970: timestamp)
        }
    }
}

// MARK: - Errors

enum SubscriptionError: Error, LocalizedError {
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed."
        case .purchaseFailed:
            return "Purchase could not be completed."
        }
    }
}
