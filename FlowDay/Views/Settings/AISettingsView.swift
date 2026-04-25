// AISettingsView.swift
// FlowDay
//
// AI is powered by FlowDay's own servers via a Supabase Edge Function — users
// no longer need to supply or manage their own API keys.

import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    hero

                    FDSettingsUI.group {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.fdGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AI is ready")
                                    .font(.fdBodySemibold)
                                    .foregroundStyle(Color.fdText)
                                Text("No API keys needed — AI runs on FlowDay's servers")
                                    .font(.fdMicro)
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }

                    FDSettingsUI.sectionHeader("What's included")

                    FDSettingsUI.group {
                        VStack(spacing: 0) {
                            featureRow(icon: "calendar.badge.clock", title: "Smart Day Planning",
                                       description: "AI builds your schedule around your energy level")
                            Divider().padding(.leading, 52)
                            featureRow(icon: "text.badge.plus", title: "Natural Language Tasks",
                                       description: "Add tasks in plain English — AI fills in the details")
                            Divider().padding(.leading, 52)
                            featureRow(icon: "list.bullet.indent", title: "Goal Breakdown",
                                       description: "Turn a big goal into actionable subtasks")
                            Divider().padding(.leading, 52)
                            featureRow(icon: "wand.and.stars", title: "AI Template Generator",
                                       description: "Describe a project and get a ready-to-use template")
                        }
                    }

                    FDSettingsUI.infoCard(
                        icon: "lock.shield",
                        title: "Your data is private",
                        message: "AI requests are authenticated with your FlowDay account. Your tasks and prompts are never used to train AI models."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("FlowDay AI")
                .font(.fdTitle2)
                .foregroundStyle(Color.fdText)

            Text("Powered by Claude (Anthropic)")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.fdAccent)
                .frame(width: 24)
                .padding(.leading, 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Text(description)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.trailing, 14)
    }
}
