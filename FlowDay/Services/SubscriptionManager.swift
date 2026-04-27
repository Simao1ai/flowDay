// SubscriptionManager.swift
// FlowDay
//
// StoreKit 2 subscription manager with freemium feature gating.
// Handles product loading, purchasing, restore, and renewal/expiration via Transaction.updates.

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

    // Pro-only features
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
    case autoSchedule
    case weeklyReport

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

    static let monthlyProductID = "flowday.pro.monthly"
    static let fallbackMonthlyPrice = "$7.99"

    private let isProBackupKey = "fd_subscription_is_pro"

    // State
    var status: SubscriptionStatus = .free
    var monthlyProduct: Product?
    var isLoading: Bool = false
    var errorMessage: String?

    /// Display price for the monthly subscription. Falls back to "$7.99" until StoreKit loads the product.
    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? Self.fallbackMonthlyPrice
    }

    // Usage tracking
    private var dailyUsage: [String: Int] = [:]
    private var lastUsageResetDate: Date?

    // nonisolated(unsafe) allows deinit (which is always nonisolated) to cancel
    // the background transaction-listener task without a main-actor hop.
    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    private init() {
        // Optimistic restore from UserDefaults backup so the UI does not flash
        // a paywall to a Pro user before StoreKit confirms entitlements.
        if UserDefaults.standard.bool(forKey: isProBackupKey) {
            status = .pro
        }
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

    /// No-op trigger to ensure the singleton (and its transaction listener) is initialized.
    /// Call once on app launch.
    func start() {}

    // MARK: - Feature Access

    /// Check if user can access a given pro feature
    func canAccess(_ feature: ProFeature) -> Bool {
        if status == .pro || status == .proTrial {
            return true
        }

        switch feature {
        case .unlimitedAI, .emailToTask, .ramble, .focusTimerLinked,
             .premiumTemplates, .attachments, .kanbanBoard, .weekView,
             .smartFilters, .projectSections, .copyLink,
             .autoSchedule, .weeklyReport,
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

    /// Load the monthly product from the App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: [Self.monthlyProductID])
            monthlyProduct = storeProducts.first { $0.id == Self.monthlyProductID }

            #if DEBUG
            print("[SubscriptionManager] Loaded monthly product: \(monthlyProduct?.displayPrice ?? "nil")")
            #endif
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            #if DEBUG
            print("[SubscriptionManager] Error loading products: \(error)")
            #endif
        }
    }

    /// Purchase the monthly subscription. Loads the product first if needed.
    @discardableResult
    func purchase() async throws -> StoreKit.Transaction? {
        if monthlyProduct == nil {
            await loadProducts()
        }
        guard let product = monthlyProduct else {
            throw SubscriptionError.productUnavailable
        }
        return try await purchase(product)
    }

    /// Purchase a specific product
    @discardableResult
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

    /// Restore previous purchases by syncing with the App Store
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }

    /// Check current subscription status from StoreKit and update the UserDefaults backup
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyProductID {
                hasActiveSubscription = true
            }
        }

        status = hasActiveSubscription ? .pro : .free
        UserDefaults.standard.set(hasActiveSubscription, forKey: isProBackupKey)
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
    case productUnavailable
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed."
        case .productUnavailable:
            return "Subscription is not available right now. Please try again."
        case .purchaseFailed:
            return "Purchase could not be completed."
        }
    }
}
