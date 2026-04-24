// PaywallView.swift
// FlowDay
//
// Full-screen paywall shown when a free user hits a feature limit.
// Displays Pro benefits, pricing toggle, and purchase/restore buttons.

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// Which feature triggered the paywall (nil = generic upgrade)
    var triggeredBy: ProFeature?

    private var subscriptionManager: SubscriptionManager { .shared }

    @State private var selectedPlan: PlanOption = .yearly
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum PlanOption {
        case monthly, yearly
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.fdBackground, Color.fdAccentLight.opacity(0.3), Color.fdBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Close button
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

                    // Hero section
                    heroSection
                        .padding(.top, 8)

                    // Feature list
                    featureList
                        .padding(.top, 32)

                    // Pricing cards
                    pricingSection
                        .padding(.top, 32)

                    // CTA button
                    purchaseButton
                        .padding(.top, 24)

                    // Restore + terms
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
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Animated icon
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
        case .unlimitedAI:
            let limit = ProAccessManager.shared.dailyAICallLimit
            return "You've used all \(limit) free AI calls today. Upgrade for unlimited conversations."
        case .emailToTask:
            return "Email to Task is a Pro feature. Let AI scan your inbox and turn emails into tasks."
        case .ramble:
            return "Voice Ramble is a Pro feature. Dictate multiple tasks hands-free."
        case .focusTimerLinked:
            return "Linking focus sessions to tasks is a Pro feature."
        case .premiumTemplates:
            return "Premium templates are for Pro members. Access curated project starter kits."
        case .attachments:
            return "File attachments are a Pro feature. Add photos and documents to your tasks."
        case .kanbanBoard:
            return "Kanban Board is a Pro feature. See your tasks in a visual, drag-and-drop board."
        case .weekView:
            return "Week View is a Pro feature. Plan and review your entire week at a glance."
        case .smartFilters:
            return "Smart Filters are a Pro feature. Create custom views to slice through your tasks."
        case .projectSections:
            return "Project Sections are a Pro feature. Organize tasks into phases or columns."
        case .copyLink:
            return "Copy Link is a Pro feature. Share individual tasks with collaborators."
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 0) {
            Text("EVERYTHING IN PRO")
                .fdSectionHeader()
                .padding(.bottom, 16)

            VStack(spacing: 14) {
                featureRow(icon: "sparkles", title: "Unlimited AI", subtitle: "Chat, plan, and create tasks without limits")
                featureRow(icon: "envelope.badge", title: "Email to Task", subtitle: "Auto-scan inbox and capture action items")
                featureRow(icon: "mic.fill", title: "Voice Ramble", subtitle: "Dictate multiple tasks hands-free")
                featureRow(icon: "paperclip", title: "Attachments", subtitle: "Add files and photos to any task")
                featureRow(icon: "rectangle.split.3x1", title: "Kanban Board", subtitle: "Visual board view for projects")
                featureRow(icon: "square.stack.3d.up", title: "Project Sections", subtitle: "Organize into phases or columns")
                featureRow(icon: "line.3.horizontal.decrease.circle", title: "Smart Filters", subtitle: "Custom task views and filters")
                featureRow(icon: "calendar.badge.clock", title: "Week View", subtitle: "Plan your full week at a glance")
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
        HStack(spacing: 12) {
            // Yearly card
            pricingCard(
                plan: .yearly,
                label: "Yearly",
                price: subscriptionManager.yearlyProduct?.displayPrice ?? "$39.99",
                period: "/year",
                badge: "SAVE 33%",
                perMonth: yearlyPerMonth
            )

            // Monthly card
            pricingCard(
                plan: .monthly,
                label: "Monthly",
                price: subscriptionManager.monthlyProduct?.displayPrice ?? "$4.99",
                period: "/month",
                badge: nil,
                perMonth: nil
            )
        }
        .padding(.horizontal, 20)
    }

    private var yearlyPerMonth: String {
        if let product = subscriptionManager.yearlyProduct {
            let monthly = product.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceFormatStyle.locale
            return formatter.string(from: monthly as NSDecimalNumber) ?? "$3.33"
        }
        return "$3.33"
    }

    private func pricingCard(
        plan: PlanOption,
        label: String,
        price: String,
        period: String,
        badge: String?,
        perMonth: String?
    ) -> some View {
        let isSelected = selectedPlan == plan

        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = plan } }) {
            VStack(spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.fdMicroBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.fdAccent)
                        .clipShape(Capsule())
                } else {
                    Text(" ")
                        .font(.fdMicroBold)
                        .padding(.vertical, 3)
                }

                Text(label)
                    .font(.fdCaptionBold)
                    .foregroundStyle(isSelected ? Color.fdText : Color.fdTextMuted)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.fdTitle2)
                        .foregroundStyle(isSelected ? Color.fdText : Color.fdTextSecondary)
                    Text(period)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                if let perMonth {
                    Text("\(perMonth)/mo")
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdAccent)
                } else {
                    Text(" ")
                        .font(.fdMicro)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.fdSurface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.fdAccent : Color.fdBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start Free Trial")
                        .font(.fdBodySemibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Color.fdAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing)
        .padding(.horizontal, 20)

        // Trial note
        .overlay(alignment: .bottom) {
            Text("7-day free trial, then auto-renews. Cancel anytime.")
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.top, 60)
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(.fdCaption)
            .foregroundStyle(Color.fdTextSecondary)

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
        let product: Product?
        switch selectedPlan {
        case .yearly:
            product = subscriptionManager.yearlyProduct
        case .monthly:
            product = subscriptionManager.monthlyProduct
        }

        guard let product else {
            errorMessage = "Product not available. Please try again later."
            showError = true
            return
        }

        isPurchasing = true
        Task {
            do {
                _ = try await subscriptionManager.purchase(product)
                await MainActor.run {
                    isPurchasing = false
                    if subscriptionManager.status == .pro {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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
    /// Usage: `.paywall(isPresented: $showPaywall, feature: .unlimitedAI)`
    func paywall(isPresented: Binding<Bool>, feature: ProFeature? = nil) -> some View {
        modifier(PaywallModifier(isPresented: isPresented, feature: feature))
    }
}

#Preview {
    PaywallView(triggeredBy: .unlimitedAI)
}
