// EmailConnectionsView.swift
// FlowDay — Email account connections settings

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Main View

struct EmailConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    @State private var showAddSheet = false
    @State private var showEmailToTask = false
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: EmailProvider? = nil

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    if !emailService.connectedAccounts.isEmpty {
                        connectedSection
                    }

                    addSection

                    if let error = emailService.connectionError {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    pasteEmailSection

                    shareSheetTipCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Email Connections")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FDSettingsUI.backButton { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEmailAccountSheet()
                    .environment(emailService)
            }
            .sheet(isPresented: $showEmailToTask) {
                EmailToTaskView()
            }
            .alert("Disconnect Account", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { providerToDisconnect = nil }
                Button("Disconnect", role: .destructive) {
                    if let provider = providerToDisconnect {
                        emailService.disconnect(provider)
                    }
                    providerToDisconnect = nil
                }
            } message: {
                if let provider = providerToDisconnect {
                    Text("Disconnect \(provider.displayName)? FlowDay will no longer scan this inbox.")
                }
            }
    }

    // MARK: - Connected Section

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                ForEach(Array(emailService.connectedAccounts.enumerated()), id: \.element.id) { index, account in
                    connectedRow(account: account)
                    if index < emailService.connectedAccounts.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func connectedRow(account: EmailAccount) -> some View {
        HStack(spacing: 12) {
            providerIcon(account.provider, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.provider.displayName)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Text(account.email)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Button {
                providerToDisconnect = account.provider
                showDisconnectAlert = true
            } label: {
                Text("Disconnect")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.fdRedLight)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Add Section

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Email Account")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                if emailService.isConnected(.gmail) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.fdGreen)
                        Text("Gmail connected")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                    .padding(16)
                } else {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.fdAccent)
                                .frame(width: 32, height: 32)

                            Text("Add Account")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    // MARK: - Paste Email Section

    private var pasteEmailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                Button {
                    showEmailToTask = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.fdAccent)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Task from Email")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Text("Paste email content and let AI extract the task")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Share Sheet Tip Card

    private var shareSheetTipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                Text("Tip: Share from any Mail app")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("Open an email in Mail, Gmail, or any email app — tap Share → FlowDay to instantly create a task from it.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorder, lineWidth: 1)
        )
    }

    // MARK: - Provider Icon

    private func providerIcon(_ provider: EmailProvider, size: CGFloat) -> some View {
        Group {
            switch provider {
            case .gmail:
                Text("G")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .outlook:
                Image(systemName: "envelope.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(Color(hex: provider.brandHex))
        )
    }
}

// MARK: - Add Email Account Sheet

struct AddEmailAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Gmail — active
                    if !emailService.isConnected(.gmail) {
                        gmailButton
                    }

                    // Outlook — coming soon
                    outlookComingSoonRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdText)
                }
            }
        }
    }

    // MARK: - Gmail Button

    private var gmailButton: some View {
        Button {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            Task {
                let success = await emailService.connectGmail(presenting: rootVC)
                if success { await MainActor.run { dismiss() } }
            }
        } label: {
            HStack(spacing: 16) {
                providerIcon(.gmail)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gmail")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Sign in with Google")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Spacer()

                if emailService.isConnecting == .gmail {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
            .padding(16)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
        .disabled(emailService.isConnecting != nil)
    }

    // MARK: - Outlook Coming Soon Row

    private var outlookComingSoonRow: some View {
        HStack(spacing: 16) {
            providerIcon(.outlook)
                .opacity(0.45)

            VStack(alignment: .leading, spacing: 2) {
                Text("Outlook")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdTextMuted)
                Text("Sign in with Microsoft")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted.opacity(0.6))
            }

            Spacer()

            Text("Coming Soon")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .opacity(0.7)
    }

    private func providerIcon(_ provider: EmailProvider) -> some View {
        Group {
            switch provider {
            case .gmail:
                Text("G")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .outlook:
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: provider.brandHex))
        )
    }
}

