// HelpFeedbackView.swift
// FlowDay

import SwiftUI

struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.sectionHeader("Help")

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Getting Started Guide", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Help Center", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Contact Support", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "My Tickets", subtitle: nil, value: nil)
                    }

                    FDSettingsUI.sectionHeader("Feedback")

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Rate FlowDay on the App Store", subtitle: nil, value: nil)
                        Divider().padding(.leading, 16)
                        FDSettingsUI.navRow(title: "Share App", subtitle: nil, value: nil)
                    }

                    FDSettingsUI.sectionHeader("Research")

                    FDSettingsUI.group {
                        FDSettingsUI.navRow(title: "Book Feedback Session", subtitle: "We'd love to hear your thoughts in a quick 15 minute call about all things FlowDay.", value: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Help & Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }
}
