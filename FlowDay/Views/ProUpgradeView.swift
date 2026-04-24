// ProUpgradeView.swift
// FlowDay — Pro upgrade sheet

import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var highlightedFeature: ProFeature? = nil

    @State private var selectedPlan: PlanOption = .yearly
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var subscriptionManager: SubscriptionManager { .shared }

    enum PlanOption { case monthly, yearly }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 8)

                    featureList
                        .padding(.top, 28)

                    pricingToggle
                        .padding(.top, 28)

                    ctaButton
                        .padding(.top, 20)

                    restoreButton
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.fdBackground)
            .navigationTitle("FlowDay Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.fdTextMuted)
                    }
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
            ZStack {
                Circle()
                    .fill(Color.fdAccent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Color.fdAccent.opacity(0.06))
                    .frame(width: 130, height: 130)
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.top, 8)

            Text("Unlock FlowDay Pro")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)

            Text("Everything you need to do your best work.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(icon: "sparkles", title: "Unlimited AI calls", subtitle: "No daily limit on Flow AI chat & planning", highlighted: highlightedFeature == .unlimitedAI)
            Divider().padding(.leading, 52)
            featureRow(icon: "envelope.badge", title: "Email to Task (AI)", subtitle: "Scan inbox and surface actionable tasks", highlighted: highlightedFeature == .emailToTask)
            Divider().padding(.leading, 52)
            featureRow(icon: "waveform", title: "Ramble voice capture", subtitle: "Dictate multiple tasks at once", highlighted: highlightedFeature == .ramble)
            Divider().padding(.leading, 52)
            featureRow(icon: "timer", title: "Linked Focus sessions", subtitle: "Link Pomodoro sessions to specific tasks", highlighted: highlightedFeature == .focusTimerLinked)
            Divider().padding(.leading, 52)
            featureRow(icon: "calendar.badge.checkmark", title: "Week view", subtitle: "7-day grid view for upcoming tasks", highlighted: highlightedFeature == .weekView)
            Divider().padding(.leading, 52)
            featureRow(icon: "rectangle.split.3x1", title: "Kanban board", subtitle: "Drag-and-drop project board view", highlighted: highlightedFeature == .kanbanBoard)
            Divider().padding(.leading, 52)
            featureRow(icon: "line.3.horizontal.decrease.circle", title: "Smart Filters", subtitle: "Overdue, high priority, no date & more", highlighted: highlightedFeature == .smartFilters)
            Divider().padding(.leading, 52)
            featureRow(icon: "paperclip", title: "Attachments", subtitle: "Add files and photos to any task", highlighted: highlightedFeature == .attachments)
            Divider().padding(.leading, 52)
            featureRow(icon: "sparkles.rectangle.stack", title: "Premium Templates", subtitle: "Curated productivity template library", highlighted: highlightedFeature == .premiumTemplates)
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func featureRow(icon: String, title: String, subtitle: String, highlighted: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(highlighted ? Color.fdAccent : Color.fdAccentLight)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(highlighted ? .white : Color.fdAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdText)
                Text(subtitle)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.fdGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Pricing Toggle

    private var pricingToggle: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                planCard(plan: .monthly, price: "$4.99/mo", label: "Monthly")
                planCard(plan: .yearly, price: "$29.99/yr", label: "Yearly · Save 50%")
            }

            if selectedPlan == .yearly {
                Text("That's just $2.50/mo — billed annually")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
    }

    private func planCard(plan: PlanOption, price: String, label: String) -> some View {
        let selected = selectedPlan == plan
        return Button { selectedPlan = plan } label: {
            VStack(spacing: 4) {
                Text(price)
                    .font(.fdBodySemibold)
                    .foregroundStyle(selected ? .white : Color.fdText)
                Text(label)
                    .font(.fdMicro)
                    .foregroundStyle(selected ? .white.opacity(0.85) : Color.fdTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.fdAccent : Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.fdAccent : Color.fdBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack(spacing: 10) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 15))
                }
                Text(isPurchasing ? "Processing…" : "Start Free Trial")
                    .font(.fdBodySemibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.fdAccent.opacity(0.35), radius: 12, y: 5)
        }
        .disabled(isPurchasing)
    }

    private var restoreButton: some View {
        Button {
            Task {
                isPurchasing = true
                await subscriptionManager.restorePurchases()
                isPurchasing = false
            }
        } label: {
            Text("Restore Purchases")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
    }

    // MARK: - Purchase

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let product: Product? = selectedPlan == .yearly
            ? subscriptionManager.yearlyProduct
            : subscriptionManager.monthlyProduct

        guard let product else {
            // Products not yet loaded — trigger load then retry
            await subscriptionManager.loadProducts()
            return
        }

        do {
            _ = try await subscriptionManager.purchase(product)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
