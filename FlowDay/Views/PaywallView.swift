// PaywallView.swift
// FlowDay
//
// Full-screen paywall shown when a free user hits a feature limit.
// Displays Pro benefits, the monthly price, and purchase/restore buttons.

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// Which feature triggered the paywall (nil = generic upgrade)
    var triggeredBy: ProFeature?

    private var subscriptionManager: SubscriptionManager { .shared }

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.fdBackground, Color.fdAccentLight.opacity(0.3), Color.fdBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    heroSection
                        .padding(.top, 8)

                    featureList
                        .padding(.top, 32)

                    pricingSection
                        .padding(.top, 32)

                    purchaseButton
                        .padding(.top, 24)

                    footerLinks
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if subscriptionManager.monthlyProduct == nil {
                await subscriptionManager.loadProducts()
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.fdAccent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.fdAccent.opacity(0.06))
                    .frame(width: 120, height: 120)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.fdAccent)
            }

            Text("Unlock FlowDay Pro")
                .font(.fdTitle)
                .foregroundStyle(Color.fdText)
                .multilineTextAlignment(.center)

            Text(triggerMessage)
                .font(.fdBody)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var triggerMessage: String {
        guard let feature = triggeredBy else {
            return "Get unlimited access to everything FlowDay has to offer."
        }
        switch feature {
        case .aiChat, .unlimitedAI:
            let limit = feature.freeLimit ?? ProAccessManager.shared.freeAILimit
            return "You've used all \(limit) of your daily AI messages. Upgrade for unlimited conversations."
        case .aiPlanning:
            let limit = feature.freeLimit ?? 0
            return "You've used all \(limit) of your daily AI plans. Upgrade for unlimited planning."
        case .unlimitedProjects:
            let limit = feature.freeLimit ?? 0
            return "You've hit the \(limit)-project limit. Upgrade to create as many as you need."
        case .customThemes:
            return "Custom themes are a Pro feature. Upgrade to personalize your FlowDay."
        case .prioritySupport:
            return "Priority support is available to Pro members."
        case .advancedAnalytics:
            return "Advanced analytics are a Pro feature. See deeper insights into your productivity."
        case .emailToTask:
            return "Email to Task scanning is a Pro feature. Let AI surface your inbox actions."
        case .ramble:
            return "Ramble voice capture is a Pro feature. Dictate multiple tasks at once."
        case .focusTimerLinked:
            return "Linking Focus sessions to tasks is a Pro feature."
        case .premiumTemplates:
            return "Premium templates are a Pro feature. Access curated productivity templates."
        case .attachments:
            return "File attachments are a Pro feature. Add files and photos to any task."
        case .kanbanBoard:
            return "Kanban board view is a Pro feature. Visualize your project as columns."
        case .weekView:
            return "Week view is a Pro feature. See all your tasks in a 7-day grid."
        case .smartFilters:
            return "Smart Filters are a Pro feature. Filter by priority, date, overdue, and more."
        case .projectSections:
            return "Project sections are a Pro feature. Organize tasks into custom columns."
        case .copyLink:
            return "Copy link is a Pro feature. Share tasks with a deep link."
        case .autoSchedule:
            return "AI Auto-Schedule is a Pro feature. Let AI plan your entire week automatically."
        case .weeklyReport:
            return "Weekly Report is a Pro feature. Get an AI-powered productivity summary every week."
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 0) {
            Text("EVERYTHING IN PRO")
                .fdSectionHeader()
                .padding(.bottom, 16)

            VStack(spacing: 14) {
                featureRow(icon: "folder.fill", title: "Unlimited Projects", subtitle: "No cap on active projects")
                featureRow(icon: "brain.head.profile", title: "Unlimited AI Planning", subtitle: "Smart task breakdowns, any time")
                featureRow(icon: "bubble.left.and.bubble.right.fill", title: "Unlimited AI Chat", subtitle: "Your personal productivity assistant")
                featureRow(icon: "paintpalette.fill", title: "Custom Themes", subtitle: "Make FlowDay yours")
                featureRow(icon: "chart.bar.fill", title: "Advanced Analytics", subtitle: "Deep productivity insights")
                featureRow(icon: "bolt.heart.fill", title: "Priority Support", subtitle: "Fast help when you need it")
            }
            .padding(.horizontal, 24)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fdAccent.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Text(subtitle)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.fdAccent)
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(subscriptionManager.monthlyDisplayPrice)
                    .font(.fdTitle)
                    .foregroundStyle(Color.fdText)
                Text("/month")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdTextSecondary)
            }

            Text("Cancel anytime in Settings")
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.fdSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fdAccent, lineWidth: 2)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe")
                        .font(.fdBodySemibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Color.fdAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing || isRestoring)
        .padding(.horizontal, 20)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button {
                Task { await handleRestore() }
            } label: {
                HStack(spacing: 4) {
                    if isRestoring {
                        ProgressView().scaleEffect(0.7)
                    }
                    Text(isRestoring ? "Restoring…" : "Restore Purchases")
                }
            }
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextSecondary)
            .disabled(isPurchasing || isRestoring)

            Text("·")
                .foregroundStyle(Color.fdTextMuted)

            Link("Privacy", destination: URL(string: "https://flowday.app/privacy")!)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)

            Text("·")
                .foregroundStyle(Color.fdTextMuted)

            Link("Terms", destination: URL(string: "https://flowday.app/terms")!)
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .padding(.top, 24)
    }

    // MARK: - Purchase Logic

    private func handlePurchase() {
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let transaction = try await subscriptionManager.purchase()
                if transaction != nil, subscriptionManager.status != .free {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handleRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        await subscriptionManager.restorePurchases()
        if subscriptionManager.status != .free {
            dismiss()
        } else if let message = subscriptionManager.errorMessage {
            errorMessage = message
            showError = true
        }
    }
}

// MARK: - View Modifier for Easy Paywall Presentation

struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    var feature: ProFeature?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView(triggeredBy: feature)
            }
    }
}

extension View {
    /// Present the paywall as a sheet.
    /// Usage: `.paywall(isPresented: $showPaywall, feature: .aiChat)`
    func paywall(isPresented: Binding<Bool>, feature: ProFeature? = nil) -> some View {
        modifier(PaywallModifier(isPresented: isPresented, feature: feature))
    }
}

#Preview {
    PaywallView(triggeredBy: .aiChat)
}
