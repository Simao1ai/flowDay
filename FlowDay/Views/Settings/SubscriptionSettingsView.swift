// SubscriptionSettingsView.swift
// FlowDay

import SwiftUI
import StoreKit

struct SubscriptionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorText = ""

    private var subscriptionManager: SubscriptionManager { .shared }

    var body: some View {
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
                        Text("FlowDay Pro")
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

                    pricingCard

                    VStack(spacing: 4) {
                        Text("Account didn't upgrade?")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                        Button {
                            Task { await restore() }
                        } label: {
                            HStack(spacing: 4) {
                                if isRestoring {
                                    ProgressView().scaleEffect(0.7)
                                }
                                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                            }
                        }
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdAccent)
                        .disabled(isPurchasing || isRestoring)
                    }
                    .frame(maxWidth: .infinity)

                    ctaButton

                    Text("Auto-renews monthly. Cancel anytime in Settings.")
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
            .task {
                if subscriptionManager.monthlyProduct == nil {
                    await subscriptionManager.loadProducts()
                }
            }
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text(subscriptionManager.monthlyDisplayPrice)
                        .font(.fdTitle3)
                        .foregroundStyle(Color.fdText)
                    Text("Billed every month")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fdAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdAccent, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(isPurchasing ? "Processing…" : "Subscribe")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fdAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isPurchasing || isRestoring)
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await subscriptionManager.purchase()
        } catch {
            errorText = error.localizedDescription
            showError = true
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        await subscriptionManager.restorePurchases()
        if subscriptionManager.status == .free, let message = subscriptionManager.errorMessage {
            errorText = message
            showError = true
        }
    }
}
