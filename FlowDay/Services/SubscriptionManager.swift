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

    // nonisolated(unsafe) allows deinit (which is always nonisolated) to cancel
    // the background transaction-listener task without a main-actor hop.
    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
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
