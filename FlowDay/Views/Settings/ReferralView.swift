// ReferralView.swift
// FlowDay — User-facing "Invite Friends" screen.

import SwiftUI

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = ReferralService.shared
    @State private var copyConfirm: String?
    @State private var isShareSheetPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                linkSection
                statsSection
                recentInvitesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color.fdBackground)
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
        }
        .task { await service.bootstrap() }
        .sheet(isPresented: $isShareSheetPresented) {
            if let url = service.shareLink {
                ShareSheet(items: [service.shareText, url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "gift.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
            Text("Bring friends to FlowDay")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("Share your link. Track who joins.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var linkSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Invite Link")
                        .font(.fdMicroBold)
                        .foregroundStyle(Color.fdTextMuted)
                        .textCase(.uppercase)
                    Text(service.shareLink?.absoluteString ?? "Generating…")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    if let link = service.shareLink {
                        UIPasteboard.general.string = link.absoluteString
                        copyConfirm = "Copied!"
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            copyConfirm = nil
                        }
                    }
                } label: {
                    Label(copyConfirm ?? "Copy", systemImage: "doc.on.doc")
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(service.shareLink == nil)

                Button {
                    Haptics.tap()
                    isShareSheetPresented = true
                    Task { await service.recordInvite(email: nil) }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.fdCaptionBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.fdAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(service.shareLink == nil)
            }
        }
    }

    private var statsSection: some View {
        let stats = service.stats
        return HStack(spacing: 12) {
            statCard(value: stats.invited, label: "Invited", color: .fdBlue)
            statCard(value: stats.joined,  label: "Joined",  color: .fdGreen)
            statCard(value: stats.active,  label: "Active",  color: .fdAccent)
        }
    }

    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Color.fdSurface
                LinearGradient(colors: [color.opacity(0.1), color.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentInvitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .textCase(.uppercase)

            if service.referrals.isEmpty {
                Text("No invites sent yet. Share your link to get started.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(service.referrals.prefix(10)) { referral in
                        HStack(spacing: 12) {
                            Image(systemName: referral.status == "completed" ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(referral.status == "completed" ? Color.fdGreen : Color.fdYellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(referral.referredEmail ?? "Shared link")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdText)
                                Text(referral.createdAt.formatted(.relative(presentation: .named)))
                                    .font(.fdMicro)
                                    .foregroundStyle(Color.fdTextMuted)
                            }
                            Spacer()
                            Text(referral.status.capitalized)
                                .font(.fdMicroBold)
                                .foregroundStyle(referral.status == "completed" ? Color.fdGreen : Color.fdYellow)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        if referral.id != service.referrals.prefix(10).last?.id {
                            Divider().padding(.leading, 38)
                        }
                    }
                }
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - UIActivityViewController bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
