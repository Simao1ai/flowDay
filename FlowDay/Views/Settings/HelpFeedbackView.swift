// HelpFeedbackView.swift
// FlowDay

import SwiftUI
import UIKit
import StoreKit

struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FDSettingsUI.sectionHeader("Help")

                FDSettingsUI.group {
                    actionRow(title: "FAQ",
                              subtitle: "Browse common questions") {
                        if let url = URL(string: "https://flowdayai.app/faq") { openURL(url) }
                    }
                    Divider().padding(.leading, 16)
                    actionRow(title: "Contact Support",
                              subtitle: "support@flowdayai.app") {
                        sendMail(to: "support@flowdayai.app",
                                 subject: "FlowDay support request")
                    }
                }

                FDSettingsUI.sectionHeader("Feedback")

                FDSettingsUI.group {
                    actionRow(title: "Feature Request",
                              subtitle: "feedback@flowdayai.app") {
                        sendMail(to: "feedback@flowdayai.app",
                                 subject: "FlowDay feature request")
                    }
                    Divider().padding(.leading, 16)
                    actionRow(title: "Report a Bug",
                              subtitle: "bugs@flowdayai.app") {
                        sendMail(to: "bugs@flowdayai.app",
                                 subject: "FlowDay bug report",
                                 body: bugReportTemplate())
                    }
                    Divider().padding(.leading, 16)
                    actionRow(title: "Rate FlowDay on the App Store",
                              subtitle: "Quick in-app rating") {
                        Task { @MainActor in requestReview() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.fdBackground)
        .navigationTitle("Help & Feedback")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
        }
    }

    // MARK: - Row builder

    private func actionRow(title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: subtitle != nil ? 4 : 0) {
                HStack {
                    Text(title)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mail

    private func sendMail(to address: String, subject: String, body: String = "") {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var items: [URLQueryItem] = [URLQueryItem(name: "subject", value: subject)]
        if !body.isEmpty { items.append(URLQueryItem(name: "body", value: body)) }
        components.queryItems = items
        guard let url = components.url else { return }
        openURL(url)
    }

    /// Pre-fills bug reports with device + app metadata so users don't have to.
    private func bugReportTemplate() -> String {
        let device = UIDevice.current
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return """


        ---
        Please describe the issue above. Auto-attached info:
        FlowDay \(version) (build \(build))
        \(device.model) · iOS \(device.systemVersion)
        """
    }
}
