// EmailConnectionsView.swift
// FlowDay — Email account connections settings

import SwiftUI
import AuthenticationServices

struct EmailConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService
    @Environment(TaskService.self) private var taskService

    @State private var showAddSheet = false
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: EmailProvider? = nil
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack {
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

                    shareFromMailCard
                    importFromEmailSection
                    infoCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Email Connections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FDSettingsUI.backButton { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEmailAccountSheet()
                    .environment(emailService)
            }
            .sheet(isPresented: $showImportSheet) {
                ShareExtensionView(
                    onSave: { parsed in
                        taskService.createTask(
                            title: parsed.title,
                            notes: parsed.notes,
                            priority: parsed.priority,
                            dueDate: parsed.dueDate
                        )
                        showImportSheet = false
                    },
                    onCancel: { showImportSheet = false }
                )
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
            providerIcon(account.provider)

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
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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

    // MARK: - Share from Mail Card

    private var shareFromMailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdAccent)
                Text("Share from Any Email App")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("Share emails from Mail, Gmail, or any email app to create tasks. Just tap Share → FlowDay in any email.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
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

    // MARK: - Import from Email Section

    private var importFromEmailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                Button {
                    showImportSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.below.ecg")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.fdAccent)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Email")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Text("Paste any email — AI turns it into a task")
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

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdAccent)
                Text("Email to Task")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("Connect your inbox and FlowDay will surface emails that need action — turning them into tasks automatically.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
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

    private func providerIcon(_ provider: EmailProvider) -> some View {
        Group {
            switch provider {
            case .gmail:
                Text("G")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .outlook:
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            case .iCloud:
                Image(systemName: "applelogo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
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
                    ForEach(availableProviders) { provider in
                        providerButton(provider)
                    }
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

    private var availableProviders: [EmailProvider] {
        // iCloud removed. Outlook always listed as Coming Soon.
        var providers: [EmailProvider] = []
        if !emailService.isConnected(.gmail) { providers.append(.gmail) }
        providers.append(.outlook)
        return providers
    }

    @ViewBuilder
    private func providerButton(_ provider: EmailProvider) -> some View {
        if provider == .outlook {
            outlookComingSoonRow
        } else {
            Button {
                connectGmail()
            } label: {
                HStack(spacing: 16) {
                    providerIcon(provider)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdText)
                        Text("Sign in with Google")
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdTextMuted)
                    }

                    Spacer()

                    if emailService.isConnecting == provider {
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
    }

    private var outlookComingSoonRow: some View {
        HStack(spacing: 16) {
            providerIcon(.outlook)

            VStack(alignment: .leading, spacing: 2) {
                Text("Outlook")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
                Text("Sign in with Microsoft")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
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
        .background(Color.fdSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func connectGmail() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        Task {
            let success = await emailService.connectGmail(presenting: rootVC)
            if success { await MainActor.run { dismiss() } }
        }
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
            case .iCloud:
                Image(systemName: "applelogo")
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
