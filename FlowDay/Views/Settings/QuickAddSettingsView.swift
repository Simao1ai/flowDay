// QuickAddSettingsView.swift
// FlowDay

import SwiftUI

struct QuickAddSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showActionLabels = true

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    FDSettingsUI.group {
                        FDSettingsUI.toggleRow(title: "Show action labels", isOn: $showActionLabels, subtitle: nil)
                    }

                    VStack(spacing: 8) {
                        Text("Example")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            actionChip("Date")
                            actionChip("Priority")
                            actionChip("Project")
                            actionChip("Duration")
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    FDSettingsUI.sectionHeader("Included Task Actions")

                    VStack(spacing: 0) {
                        taskActionRow(icon: "calendar", title: "Date", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "flag.fill", title: "Priority", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "folder.fill", title: "Project", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "clock.fill", title: "Duration", isIncluded: true)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "bell.fill", title: "Reminders", isIncluded: true)
                    }
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    FDSettingsUI.sectionHeader("More Task Actions")

                    VStack(spacing: 0) {
                        taskActionRow(icon: "tag.fill", title: "Labels", isIncluded: false)
                        Divider().padding(.leading, 52)
                        taskActionRow(icon: "calendar.badge.plus", title: "Start Date", isIncluded: false)
                        Divider().padding(.leading, 52)
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.fdGreen)
                                .frame(width: 28)
                            Text("Cognitive Load")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.fdYellow)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.fdYellowLight)
                                .clipShape(Capsule())
                            Spacer()
                            Image(systemName: "line.3")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
    }

    private func actionChip(_ label: String) -> some View {
        Text(label)
            .font(.fdCaption)
            .foregroundStyle(Color.fdText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.fdAccentLight)
            .clipShape(Capsule())
    }

    private func taskActionRow(icon: String, title: String, isIncluded: Bool) -> some View {
        HStack(spacing: 12) {
            if isIncluded {
                Button { } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.fdRed)
                }
            } else {
                Button { } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.fdGreen)
                }
            }

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextSecondary)
                .frame(width: 20)

            Text(title)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)

            Spacer()

            Image(systemName: "line.3")
                .font(.system(size: 14))
                .foregroundStyle(Color.fdTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
