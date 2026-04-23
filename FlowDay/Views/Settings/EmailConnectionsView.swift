// EmailConnectionsView.swift
// FlowDay — Email account connections settings

import SwiftUI
import AuthenticationServices

struct EmailConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    @State private var showAddSheet = false
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: EmailProvider? = nil

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
                let available = EmailProvider.allCases.filter { !emailService.isConnected($0) }

                if available.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.fdGreen)
                        Text("All email accounts connected")
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
            Text("Connect your inboxes and FlowDay will surface emails that need action — turning them into tasks automatically.")
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

    @State private var showICloudForm = false

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
            .sheet(isPresented: $showICloudForm) {
                ICloudCredentialsSheet()
                    .environment(emailService)
                    .onDisappear {
                        if emailService.isConnected(.iCloud) { dismiss() }
                    }
            }
        }
    }

    private var availableProviders: [EmailProvider] {
        EmailProvider.allCases.filter { !emailService.isConnected($0) }
    }

    @ViewBuilder
    private func providerButton(_ provider: EmailProvider) -> some View {
        Button {
            connectProvider(provider)
        } label: {
            HStack(spacing: 16) {
                providerIcon(provider)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text(providerSubtitle(provider))
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

    private func providerSubtitle(_ provider: EmailProvider) -> String {
        switch provider {
        case .gmail:   "Sign in with Google"
        case .outlook: "Sign in with Microsoft"
        case .iCloud:  "Use an app-specific password"
        }
    }

    private func connectProvider(_ provider: EmailProvider) {
        switch provider {
        case .gmail:
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            Task {
                let success = await emailService.connectGmail(presenting: rootVC)
                if success { await MainActor.run { dismiss() } }
            }

        case .outlook:
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            Task {
                let success = await emailService.connectOutlook(anchor: window)
                if success { await MainActor.run { dismiss() } }
            }

        case .iCloud:
            showICloudForm = true
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

// MARK: - iCloud Credentials Sheet

struct ICloudCredentialsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    @State private var email = ""
    @State private var appPassword = ""
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    instructionCard

                    FDSettingsUI.group {
                        VStack(spacing: 0) {
                            fieldRow(label: "iCloud Email", placeholder: "you@icloud.com", text: $email, keyboard: .emailAddress)
                            Divider().padding(.leading, 16)
                            secureFieldRow(label: "App-Specific Password", placeholder: "xxxx-xxxx-xxxx-xxxx", text: $appPassword)
                        }
                    }

                    connectButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("iCloud Mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdText)
                }
            }
        }
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color.fdAccent)
                Text("App-Specific Password Required")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("Apple requires an app-specific password for third-party apps. Generate one at appleid.apple.com under Sign-In and Security.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fdBorder, lineWidth: 1))
    }

    private func fieldRow(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
            TextField(placeholder, text: text)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(16)
    }

    private func secureFieldRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
            SecureField(placeholder, text: text)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(16)
    }

    private var connectButton: some View {
        Button {
            Task {
                isConnecting = true
                let success = await emailService.connectICloud(email: email, appPassword: appPassword)
                isConnecting = false
                if success { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                }
                Text(isConnecting ? "Connecting…" : "Connect iCloud Mail")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canConnect ? Color.fdAccent : Color.fdSurfaceHover)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canConnect || isConnecting)
    }

    private var canConnect: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !appPassword.isEmpty
    }
}
