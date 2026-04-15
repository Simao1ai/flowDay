// CalendarAccountManager.swift
// FlowDay — Multi-provider calendar account management
//
// Manages OAuth tokens and account state for Apple, Google, and Microsoft calendars.
// Tokens are stored securely in Keychain via KeychainHelper.

import Foundation
import AuthenticationServices
import GoogleSignIn

// MARK: - Calendar Provider

enum CalendarProvider: String, CaseIterable, Codable, Identifiable {
    case apple = "apple"
    case google = "google"
    case microsoft = "microsoft"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple Calendar"
        case .google: "Google Calendar"
        case .microsoft: "Outlook Calendar"
        }
    }

    var iconName: String {
        switch self {
        case .apple: "applelogo"
        case .google: "g.circle.fill"
        case .microsoft: "envelope.fill"
        }
    }

    var brandColor: String {
        switch self {
        case .apple: "000000"
        case .google: "4285F4"
        case .microsoft: "0078D4"
        }
    }
}

// MARK: - Connected Account

struct CalendarAccount: Codable, Identifiable {
    var id: String { provider.rawValue }
    let provider: CalendarProvider
    var email: String
    var isConnected: Bool
    var connectedAt: Date
}

// MARK: - Calendar Account Manager

@Observable
final class CalendarAccountManager {

    var connectedAccounts: [CalendarAccount] = []
    var isConnecting: CalendarProvider? = nil
    var connectionError: String? = nil

    // Keychain keys
    private let accountsKey = "calendar_connected_accounts"
    private let googleTokenKey = "calendar_google_access_token"
    private let googleRefreshKey = "calendar_google_refresh_token"
    private let microsoftTokenKey = "calendar_microsoft_access_token"
    private let microsoftRefreshKey = "calendar_microsoft_refresh_token"

    // Google OAuth Config — replace with your own client ID from Google Cloud Console
    // You'll need to create an OAuth 2.0 Client ID for iOS at:
    // https://console.cloud.google.com/apis/credentials
    // Enable the Google Calendar API in your project.
    private let googleCalendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    // Microsoft OAuth Config — replace with your own client ID from Azure Portal
    // Register an app at: https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps
    // Add "Calendars.Read" permission under Microsoft Graph
    private let microsoftClientId = "YOUR_MICROSOFT_CLIENT_ID"
    private let microsoftTenantId = "common"
    private let microsoftRedirectScheme = "msauth.io.flowday.app"
    private let microsoftCalendarScope = "Calendars.Read"

    init() {
        loadAccounts()
    }

    // MARK: - Account State

    func isConnected(_ provider: CalendarProvider) -> Bool {
        connectedAccounts.contains { $0.provider == provider && $0.isConnected }
    }

    func account(for provider: CalendarProvider) -> CalendarAccount? {
        connectedAccounts.first { $0.provider == provider }
    }

    // MARK: - Apple Calendar (EventKit)

    func connectAppleCalendar() async -> Bool {
        await MainActor.run { isConnecting = .apple }

        let calendarService = CalendarService()
        let granted = await calendarService.requestAccess()

        await MainActor.run {
            if granted {
                let account = CalendarAccount(
                    provider: .apple,
                    email: "Apple Calendar",
                    isConnected: true,
                    connectedAt: .now
                )
                updateAccount(account)
            } else {
                connectionError = "Calendar access was denied. Please enable it in Settings > Privacy > Calendars."
            }
            isConnecting = nil
        }

        return granted
    }

    // MARK: - Google Calendar (Google Sign-In + Calendar API)

    func connectGoogleCalendar(presenting viewController: UIViewController) async -> Bool {
        await MainActor.run {
            isConnecting = .google
            connectionError = nil
        }

        // Use Google Sign-In SDK with calendar scope
        let additionalScopes = [googleCalendarScope]

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: additionalScopes
            )

            let user = result.user
            let email = user.profile?.email ?? "Google Account"

            // Store the access token for Calendar API calls
            if let accessToken = user.accessToken.tokenString as String? {
                KeychainHelper.shared.saveString(accessToken, for: googleTokenKey)
            }

            // Store refresh token if available
            if let refreshToken = user.refreshToken.tokenString as String? {
                KeychainHelper.shared.saveString(refreshToken, for: googleRefreshKey)
            }

            let account = CalendarAccount(
                provider: .google,
                email: email,
                isConnected: true,
                connectedAt: .now
            )

            await MainActor.run {
                updateAccount(account)
                isConnecting = nil
            }

            return true

        } catch {
            await MainActor.run {
                connectionError = "Google sign-in failed: \(error.localizedDescription)"
                isConnecting = nil
            }
            return false
        }
    }

    /// Fetch Google Calendar events for a given date range
    func fetchGoogleCalendarEvents(startDate: Date, endDate: Date) async -> [ExternalCalendarEvent] {
        guard let token = KeychainHelper.shared.readString(for: googleTokenKey) else { return [] }

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // If 401, try refreshing the token
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if await refreshGoogleToken() {
                    return await fetchGoogleCalendarEvents(startDate: startDate, endDate: endDate)
                }
                return []
            }

            let decoded = try JSONDecoder().decode(GoogleCalendarResponse.self, from: data)

            return decoded.items?.compactMap { item in
                guard let start = item.startDateTime, let end = item.endDateTime else { return nil }
                return ExternalCalendarEvent(
                    id: item.id ?? UUID().uuidString,
                    title: item.summary ?? "Untitled",
                    startDate: start,
                    endDate: end,
                    isAllDay: item.start?.date != nil,
                    provider: .google,
                    calendarName: "Google Calendar"
                )
            } ?? []

        } catch {
            print("Google Calendar fetch error: \(error)")
            return []
        }
    }

    private func refreshGoogleToken() async -> Bool {
        // Use GIDSignIn to restore/refresh the session
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try await user.refreshTokensIfNeeded()
            if let newToken = user.accessToken.tokenString as String? {
                KeychainHelper.shared.saveString(newToken, for: googleTokenKey)
            }
            return true
        } catch {
            print("Google token refresh failed: \(error)")
            return false
        }
    }

    // MARK: - Microsoft Outlook (ASWebAuthenticationSession + Graph API)

    func connectMicrosoftCalendar(anchor: ASPresentationAnchor) async -> Bool {
        await MainActor.run {
            isConnecting = .microsoft
            connectionError = nil
        }

        let authURL = buildMicrosoftAuthURL()

        guard let url = authURL else {
            await MainActor.run {
                connectionError = "Failed to build Microsoft auth URL."
                isConnecting = nil
            }
            return false
        }

        // Use ASWebAuthenticationSession for OAuth
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: microsoftRedirectScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                if let error = error {
                    Task { @MainActor in
                        self.connectionError = "Microsoft sign-in cancelled or failed."
                        self.isConnecting = nil
                    }
                    continuation.resume(returning: false)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    Task { @MainActor in
                        self.connectionError = "No authorization code received."
                        self.isConnecting = nil
                    }
                    continuation.resume(returning: false)
                    return
                }

                // Exchange code for tokens
                Task {
                    let success = await self.exchangeMicrosoftCode(code)
                    continuation.resume(returning: success)
                }
            }

            // Present the auth session
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func buildMicrosoftAuthURL() -> URL? {
        var components = URLComponents(string: "https://login.microsoftonline.com/\(microsoftTenantId)/oauth2/v2.0/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: microsoftClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "\(microsoftRedirectScheme)://auth"),
            URLQueryItem(name: "scope", value: "\(microsoftCalendarScope) offline_access openid profile email"),
            URLQueryItem(name: "response_mode", value: "query"),
        ]
        return components?.url
    }

    private func exchangeMicrosoftCode(_ code: String) async -> Bool {
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(microsoftTenantId)/oauth2/v2.0/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(microsoftClientId)",
            "code=\(code)",
            "redirect_uri=\(microsoftRedirectScheme)://auth",
            "grant_type=authorization_code",
            "scope=\(microsoftCalendarScope) offline_access openid profile email"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(MicrosoftTokenResponse.self, from: data)

            KeychainHelper.shared.saveString(tokenResponse.accessToken, for: microsoftTokenKey)
            if let refresh = tokenResponse.refreshToken {
                KeychainHelper.shared.saveString(refresh, for: microsoftRefreshKey)
            }

            // Fetch user email from Microsoft Graph
            let email = await fetchMicrosoftUserEmail(token: tokenResponse.accessToken)

            let account = CalendarAccount(
                provider: .microsoft,
                email: email ?? "Outlook Account",
                isConnected: true,
                connectedAt: .now
            )

            await MainActor.run {
                updateAccount(account)
                isConnecting = nil
            }

            return true

        } catch {
            await MainActor.run {
                connectionError = "Failed to complete Microsoft sign-in."
                isConnecting = nil
            }
            return false
        }
    }

    private func fetchMicrosoftUserEmail(token: String) async -> String? {
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

    /// Fetch Microsoft calendar events for a given date range
    func fetchMicrosoftCalendarEvents(startDate: Date, endDate: Date) async -> [ExternalCalendarEvent] {
        guard let token = KeychainHelper.shared.readString(for: microsoftTokenKey) else { return [] }

        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        let urlString = "https://graph.microsoft.com/v1.0/me/calendarview?startDateTime=\(startStr)&endDateTime=\(endStr)&$orderby=start/dateTime"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if await refreshMicrosoftToken() {
                    return await fetchMicrosoftCalendarEvents(startDate: startDate, endDate: endDate)
                }
                return []
            }

            let decoded = try JSONDecoder().decode(MicrosoftCalendarResponse.self, from: data)

            return decoded.value?.compactMap { event in
                guard let start = event.startDateTime, let end = event.endDateTime else { return nil }
                return ExternalCalendarEvent(
                    id: event.id ?? UUID().uuidString,
                    title: event.subject ?? "Untitled",
                    startDate: start,
                    endDate: end,
                    isAllDay: event.isAllDay ?? false,
                    provider: .microsoft,
                    calendarName: "Outlook Calendar"
                )
            } ?? []

        } catch {
            print("Microsoft Calendar fetch error: \(error)")
            return []
        }
    }

    private func refreshMicrosoftToken() async -> Bool {
        guard let refreshToken = KeychainHelper.shared.readString(for: microsoftRefreshKey) else { return false }

        let tokenURL = URL(string: "https://login.microsoftonline.com/\(microsoftTenantId)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(microsoftClientId)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token",
            "scope=\(microsoftCalendarScope) offline_access openid profile email"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(MicrosoftTokenResponse.self, from: data)
            KeychainHelper.shared.saveString(tokenResponse.accessToken, for: microsoftTokenKey)
            if let refresh = tokenResponse.refreshToken {
                KeychainHelper.shared.saveString(refresh, for: microsoftRefreshKey)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Disconnect

    func disconnect(_ provider: CalendarProvider) {
        switch provider {
        case .apple:
            // Apple Calendar uses system permissions — can't revoke from app
            break
        case .google:
            GIDSignIn.sharedInstance.signOut()
            KeychainHelper.shared.delete(for: googleTokenKey)
            KeychainHelper.shared.delete(for: googleRefreshKey)
        case .microsoft:
            KeychainHelper.shared.delete(for: microsoftTokenKey)
            KeychainHelper.shared.delete(for: microsoftRefreshKey)
        }

        connectedAccounts.removeAll { $0.provider == provider }
        saveAccounts()
    }

    // MARK: - Persistence

    private func updateAccount(_ account: CalendarAccount) {
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
        if let data = KeychainHelper.shared.read(for: accountsKey),
           let accounts = try? JSONDecoder().decode([CalendarAccount].self, from: data) {
            connectedAccounts = accounts

            // Verify Apple Calendar is still authorized
            if let appleAccount = accounts.first(where: { $0.provider == .apple && $0.isConnected }) {
                let status = EKEventStore.authorizationStatus(for: .event)
                if status != .fullAccess {
                    disconnect(.apple)
                }
            }
        }
    }
}

// MARK: - Unified External Calendar Event

struct ExternalCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let provider: CalendarProvider
    let calendarName: String
}

// MARK: - Google Calendar API Response Models

struct GoogleCalendarResponse: Codable {
    let items: [GoogleCalendarItem]?
}

struct GoogleCalendarItem: Codable {
    let id: String?
    let summary: String?
    let start: GoogleDateTime?
    let end: GoogleDateTime?

    var startDateTime: Date? {
        if let dateTime = start?.dateTime {
            return ISO8601DateFormatter().date(from: dateTime)
        } else if let dateStr = start?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr)
        }
        return nil
    }

    var endDateTime: Date? {
        if let dateTime = end?.dateTime {
            return ISO8601DateFormatter().date(from: dateTime)
        } else if let dateStr = end?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr)
        }
        return nil
    }
}

struct GoogleDateTime: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}

// MARK: - Microsoft Graph API Response Models

struct MicrosoftTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct MicrosoftCalendarResponse: Codable {
    let value: [MicrosoftCalendarEvent]?
}

struct MicrosoftCalendarEvent: Codable {
    let id: String?
    let subject: String?
    let isAllDay: Bool?
    let start: MicrosoftDateTime?
    let end: MicrosoftDateTime?

    var startDateTime: Date? {
        guard let dateTime = start?.dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateTime) ?? ISO8601DateFormatter().date(from: dateTime)
    }

    var endDateTime: Date? {
        guard let dateTime = end?.dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateTime) ?? ISO8601DateFormatter().date(from: dateTime)
    }
}

struct MicrosoftDateTime: Codable {
    let dateTime: String?
    let timeZone: String?
}

// MARK: - EventKit import for auth status check
import EventKit
