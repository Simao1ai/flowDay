// SubscriptionSettingsView.swift
// FlowDay

import SwiftUI
import StoreKit

struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: String = "yearly"
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorText = ""

    private var subscriptionManager: SubscriptionManager { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                    .padding(.bottom, 8)

                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 100, height: 100)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.fdAccent, Color.fdAccentSoft]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())

                    VStack(spacing: 8) {
                        Text("Try Pro for Free")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text("Supercharge your productivity")
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdTextSecondary)
                        Text("Get the full FlowDay experience")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Circle().fill(Color.fdAccent).frame(width: 6, height: 6)
                        Circle().fill(Color.fdBorder).frame(width: 6, height: 6)
                        Circle().fill(Color.fdBorder).frame(width: 6, height: 6)
                    }

                    pricingCards

                    VStack(spacing: 4) {
                        Text("Account didn't upgrade?")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                        Button("Refresh Subscription") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdAccent)
                    }
                    .frame(maxWidth: .infinity)

                    Text("Due today: $0.00")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)

                    ctaButton

                    Text("All FlowDay features. Free 7-day trial. Cancel anytime.")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationBarHidden(true)
            .alert("Subscription", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorText)
            }
        }
    }

    private var pricingCards: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.pick()
                selectedPlan = "yearly"
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pay Yearly")
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdText)
                            Text(subscriptionManager.yearlyProduct?.displayPrice ?? "$49.99")
                                .font(.fdTitle3)
                                .foregroundStyle(Color.fdText)
                            Text("$4.17/mo")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Save $23.89")
                                .font(.fdMicroBold)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.fdAccent)
                                .clipShape(Capsule())
                            Image(systemName: selectedPlan == "yearly" ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.fdAccent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.fdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedPlan == "yearly" ? Color.fdAccent : Color.fdBorder, lineWidth: selectedPlan == "yearly" ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.pick()
                selectedPlan = "monthly"
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pay Monthly")
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdText)
                            Text(subscriptionManager.monthlyProduct?.displayPrice ?? "$5.99")
                                .font(.fdTitle3)
                                .foregroundStyle(Color.fdText)
                            Text("$5.99/mo")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                        Spacer()
                        Image(systemName: selectedPlan == "monthly" ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.fdAccent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.fdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedPlan == "monthly" ? Color.fdAccent : Color.fdBorder, lineWidth: selectedPlan == "monthly" ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var ctaButton: some View {
        Button {
            Task {
                isPurchasing = true
                defer { isPurchasing = false }

                let product: Product? = selectedPlan == "yearly"
                    ? subscriptionManager.yearlyProduct
                    : subscriptionManager.monthlyProduct

                guard let product else {
                    errorText = "Subscriptions are not yet available. Products will be available soon — thank you for your patience!"
                    showError = true
                    return
                }

                do {
                    _ = try await subscriptionManager.purchase(product)
                } catch {
                    errorText = error.localizedDescription
                    showError = true
                }
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text("Continue to Free Trial")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fdAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isPurchasing)
    }
}
