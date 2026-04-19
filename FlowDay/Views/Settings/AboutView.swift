// AboutView.swift
// FlowDay

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("FlowDay 1.0.0")
                            .font(.fdTitle2)
                            .foregroundStyle(Color.fdText)
                        Text("(1)")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "View changelog", subtitle: nil, value: nil)
                    }

                    Divider()

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Visit flowday.app", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Visit for inspiration", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "We are hiring!", subtitle: nil, value: nil)
                    }

                    FDSettingsUI.sectionHeader("Legal")

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Acknowledgments", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Privacy Policy", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Security Policy", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Terms of Service", subtitle: nil, value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }
}
