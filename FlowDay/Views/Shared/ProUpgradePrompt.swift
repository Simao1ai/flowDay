// ProUpgradePrompt.swift
// FlowDay
//
// Inline gate view shown in place of Pro-only content.
// Usage: if proAccessManager.isFeatureAvailable(.feature) { ... } else { ProUpgradePrompt(feature: .feature) }

import SwiftUI

struct ProUpgradePrompt: View {
    let feature: ProFeature
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.fdAccent.opacity(0.1))
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(Color.fdAccent.opacity(0.05))
                    .frame(width: 100, height: 100)
                Image(systemName: feature.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.fdAccent)
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdAccent)
                    Text("Pro Feature")
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.fdAccent.opacity(0.1))
                .clipShape(Capsule())

                Text(feature.displayName)
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)

                Text(feature.benefitDescription)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Upgrade to Pro")
                }
                .font(.fdBodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.fdAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Text("$4.99/month · 7-day free trial")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fdBackground)
        .paywall(isPresented: $showPaywall, feature: feature)
    }
}

// MARK: - Inline Banner variant (for row-level gating)

struct ProUpgradeBanner: View {
    let feature: ProFeature
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.fdAccent.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: feature.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.fdAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.displayName)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Upgrade to Pro to unlock")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Pro")
                        .font(.fdCaptionBold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.fdAccent)
                .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fdAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProUpgradePrompt(feature: .ramble)
}
