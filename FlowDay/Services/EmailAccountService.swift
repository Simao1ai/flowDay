// EmailAccountService.swift
// FlowDay — Multi-provider email account management
//
// Manages OAuth tokens for Gmail and Outlook.
// Tokens are stored securely in Keychain via KeychainHelper.

import Foundation
import AuthenticationServices
import GoogleSignIn

// MARK: - Email Provider

enum EmailProvider: String, CaseIterable, Codable, Identifiable {
    case gmail   = "gmail"
    case outlook = "outlook"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gmail:   "Gmail"
        case .outlook: "Outlook"
        }
    }

    var iconSystemName: String {
        switch self {
        case .gmail:   "envelope.fill"
        case .outlook: "envelope.badge.fill"
        }
    }

    var brandHex: String {
        switch self {
        case .gmail:   "EA4335"
        case .outlook: "0078D4"
        }
    }
}

// MARK: - Email Account

struct EmailAccount: Codable, Identifiable {
    let id: String
    let provider: EmailProvider
    var email: String
    var connectedAt: Date
}

// MARK: - Email Account Service

@Observable
final class EmailAccountService {

    var connectedAccounts: [EmailAccount] = []
    var isConnecting: EmailProvider? = nil
    var connectionError: String? = nil

    // Keychain keys
    private let accountsKey       = "email_connected_accounts"
    private let gmailTokenKey     = "email_gmail_access_token"
    private let gmailRefreshKey   = "email_gmail_refresh_token"
    private let outlookTokenKey   = "email_outlook_access_token"
    private let outlookRefreshKey = "email_outlook_refresh_token"

    // Gmail scope — read-only access to inbox
    private let gmailScope = "https://www.googleapis.com/auth/gmail.readonly"

    // Microsoft OAuth config — replace client ID with one registered in Azure Portal
    // Register at https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps
    // Add "Mail.Read" permission under Microsoft Graph
    private let outlookClientId       = "YOUR_MICROSOFT_CLIENT_ID"
    private let outlookTenantId       = "common"
    private let outlookRedirectScheme = "msauth.io.flowday.app"
    private let outlookScope          = "Mail.Read"

    init() {
        loadAccounts()
    }

    // MARK: - Account State

    func isConnected(_ provider: EmailProvider) -> Bool {
        connectedAccounts.contains { $0.provider == provider }
    }

    func account(for provider: EmailProvider) -> EmailAccount? {
        connectedAccounts.first { $0.provider == provider }
    }

    func listConnections() -> [EmailAccount] { connectedAccounts }

    // MARK: - Gmail (Google Sign-In + gmail.readonly scope)

    func connectGmail(presenting viewController: UIViewController) async -> Bool {
        await MainActor.run {
            isConnecting = .gmail
            connectionError = nil
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: [gmailScope]
            )

            let user = result.user
            let email = user.profile?.email ?? "Gmail Account"

            if let token = user.accessToken.tokenString as String? {
                KeychainHelper.shared.saveString(token, for: gmailTokenKey)
            }
            if let refresh = user.refreshToken.tokenString as String? {
                KeychainHelper.shared.saveString(refresh, for: gmailRefreshKey)
            }

            let account = EmailAccount(
                id: EmailProvider.gmail.rawValue,
                provider: .gmail,
                email: email,
                connectedAt: .now
            )

            await MainActor.run {
                upsertAccount(account)
                isConnecting = nil
            }

            return true

        } catch {
            await MainActor.run {
                connectionError = "Gmail sign-in failed: \(error.localizedDescription)"
                isConnecting = nil
            }
            return false
        }
    }

    func refreshGmailToken() async -> Bool {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try await user.refreshTokensIfNeeded()
            if let token = user.accessToken.tokenString as String? {
                KeychainHelper.shared.saveString(token, for: gmailTokenKey)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Outlook (ASWebAuthenticationSession + Microsoft Graph)

    func connectOutlook(anchor: ASPresentationAnchor) async -> Bool {
        await MainActor.run {
            isConnecting = .outlook
            connectionError = nil
        }

        guard let authURL = buildOutlookAuthURL() else {
            await MainActor.run {
                connectionError = "Failed to build Outlook auth URL."
                isConnecting = nil
            }
            return false
        }

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: outlookRedirectScheme
            ) { [weak self] callbackURL, error in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                if error != nil {
                    Task { @MainActor in
                        self.connectionError = "Outlook sign-in cancelled or failed."
                        self.isConnecting = nil
                    }
                    continuation.resume(returning: false)
                    return
                }

                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    Task { @MainActor in
                        self.connectionError = "No authorization code received."
                        self.isConnecting = nil
                    }
                    continuation.resume(returning: false)
                    return
                }

                Task {
                    let success = await self.exchangeOutlookCode(code)
                    continuation.resume(returning: success)
                }
            }

            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func buildOutlookAuthURL() -> URL? {
        var components = URLComponents(
            string: "https://login.microsoftonline.com/\(outlookTenantId)/oauth2/v2.0/authorize"
        )
        components?.queryItems = [
            URLQueryItem(name: "client_id",     value: outlookClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri",  value: "\(outlookRedirectScheme)://auth"),
            URLQueryItem(name: "scope",         value: "\(outlookScope) offline_access openid profile email"),
            URLQueryItem(name: "response_mode", value: "query"),
        ]
        return components?.url
    }

    private func exchangeOutlookCode(_ code: String) async -> Bool {
        guard let tokenURL = URL(string: "https://login.microsoftonline.com/\(outlookTenantId)/oauth2/v2.0/token") else {
            return false
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "client_id=\(outlookClientId)",
            "code=\(code)",
            "redirect_uri=\(outlookRedirectScheme)://auth",
            "grant_type=authorization_code",
            "scope=\(outlookScope) offline_access openid profile email",
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(OutlookTokenResponse.self, from: data)

            KeychainHelper.shared.saveString(tokenResponse.accessToken, for: outlookTokenKey)
            if let refresh = tokenResponse.refreshToken {
                KeychainHelper.shared.saveString(refresh, for: outlookRefreshKey)
            }

            let email = await fetchOutlookUserEmail(token: tokenResponse.accessToken)
            let account = EmailAccount(
                id: EmailProvider.outlook.rawValue,
                provider: .outlook,
                email: email ?? "Outlook Account",
                connectedAt: .now
            )

            await MainActor.run {
                upsertAccount(account)
                isConnecting = nil
            }

            return true

        } catch {
            await MainActor.run {
                connectionError = "Failed to complete Outlook sign-in."
                isConnecting = nil
            }
            return false
        }
    }

    private func fetchOutlookUserEmail(token: String) async -> String? {
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["mail"] as? String ?? json?["userPrincipalName"] as? String
        } catch {
            return nil
        }
    }

    func refreshOutlookToken() async -> Bool {
        guard let refreshToken = KeychainHelper.shared.readString(for: outlookRefreshKey),
              let tokenURL = URL(string: "https://login.microsoftonline.com/\(outlookTenantId)/oauth2/v2.0/token") else {
            return false
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "client_id=\(outlookClientId)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token",
            "scope=\(outlookScope) offline_access openid profile email",
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(OutlookTokenResponse.self, from: data)
            KeychainHelper.shared.saveString(tokenResponse.accessToken, for: outlookTokenKey)
            if let refresh = tokenResponse.refreshToken {
                KeychainHelper.shared.saveString(refresh, for: outlookRefreshKey)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Disconnect

    func disconnect(_ provider: EmailProvider) {
        switch provider {
        case .gmail:
            KeychainHelper.shared.delete(for: gmailTokenKey)
            KeychainHelper.shared.delete(for: gmailRefreshKey)
        case .outlook:
            KeychainHelper.shared.delete(for: outlookTokenKey)
            KeychainHelper.shared.delete(for: outlookRefreshKey)
        }

        connectedAccounts.removeAll { $0.provider == provider }
        saveAccounts()
    }

    // MARK: - Token Access (for EmailFetchService)

    func accessToken(for provider: EmailProvider) -> String? {
        switch provider {
        case .gmail:   KeychainHelper.shared.readString(for: gmailTokenKey)
        case .outlook: KeychainHelper.shared.readString(for: outlookTokenKey)
        }
    }

    // MARK: - Persistence

    private func upsertAccount(_ account: EmailAccount) {
        if let index = connectedAccounts.firstIndex(where: { $0.provider == account.provider }) {
            connectedAccounts[index] = account
        } else {
            connectedAccounts.append(account)
        }
        saveAccounts()
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(connectedAccounts) {
            KeychainHelper.shared.save(data, for: accountsKey)
        }
    }

    private func loadAccounts() {
        guard let data = KeychainHelper.shared.read(for: accountsKey),
              let accounts = try? JSONDecoder().decode([EmailAccount].self, from: data) else { return }
        connectedAccounts = accounts
    }
}

// MARK: - Response Models

private struct OutlookTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}
