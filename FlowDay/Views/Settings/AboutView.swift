// AboutView.swift
// FlowDay

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "FlowDay \(version)"
    }

    private var buildString: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Build \(build)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(versionString)
                        .font(.fdTitle2)
                        .foregroundStyle(Color.fdText)
                    Text(buildString)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)

                    Text("Made with ❤️ by Simao Alves")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

                FDSettingsUI.group {
                    linkRow(title: "Visit flowdayai.app",
                            url: "https://flowdayai.app")
                    Divider().padding(.leading, 16)
                    NavigationLink(destination: WhatsNewView()) {
                        FDSettingsUI.navRow(title: "View changelog", subtitle: nil, value: nil)
                    }
                    .buttonStyle(.plain)
                }

                FDSettingsUI.sectionHeader("Legal")

                FDSettingsUI.group {
                    linkRow(title: "Privacy Policy",
                            url: "https://flowdayai.app/privacy")
                    Divider().padding(.leading, 16)
                    linkRow(title: "Terms of Service",
                            url: "https://flowdayai.app/terms")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.fdBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
        }
    }

    private func linkRow(title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) { openURL(url) }
        } label: {
            HStack {
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
