// FlowDay
// AuthManager.swift
//
// Keychain-based authentication manager.
// Sign in with Apple saves credentials locally via KeychainHelper.
// Supabase SDK is bypassed due to a SIGABRT crash in SupabaseClient init
// on iOS 26.x. Data sync uses direct REST calls instead (see SupabaseService).

import Foundation
import AuthenticationServices
import GoogleSignIn
import os.log

// MARK: - Models

enum AuthProvider: String, Codable {
    case apple
    case google
    case email
}

struct FDUser: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let avatarURL: String?
    let provider: AuthProvider

    init(id: UUID = UUID(), name: String, email: String, avatarURL: String? = nil, provider: AuthProvider) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.provider = provider
    }
}

// MARK: - AuthManager

@Observable @MainActor
final class AuthManager {

    // MARK: - State

    var isAuthenticated: Bool = false
    var currentUser: FDUser?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Private

    private let logger = Logger(subsystem: "io.flowday.auth", category: "AuthManager")
    private let keychain = KeychainHelper.shared
    private let userKey = "io.flowday.auth.user"

    // MARK: - Init

    init() {}

    // MARK: - Session restore

    /// Restore auth state from Keychain. Call on app launch.
    func restoreSession() {
        isLoading = true
        defer { isLoading = false }

        guard let data = keychain.read(for: userKey),
              let user = try? JSONDecoder().decode(FDUser.self, from: data) else {
            isAuthenticated = false
            currentUser = nil
            logger.debug("No stored session in Keychain")
            return
        }

        currentUser = user
        isAuthenticated = true
        logger.info("Session restored for \(user.email)")
    }

    // MARK: - Sign in with Apple

    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid Apple ID credential"
            logger.error("Could not cast to ASAuthorizationAppleIDCredential")
            return
        }

        // Extract email — Apple only provides it on first sign-in
        let email = credential.email
            ?? keychain.read(for: "io.flowday.auth.appleemail").flatMap { String(data: $0, encoding: .utf8) }
            ?? "apple-user@private.relay"

        // Save email for future sign-ins (Apple only gives it once)
        if let providedEmail = credential.email,
           let emailData = providedEmail.data(using: .utf8) {
            keychain.save(emailData, for: "io.flowday.auth.appleemail")
        }

        let fullName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespaces)

        let user = FDUser(
            id: UUID(uuidString: credential.user) ?? UUID(),
            name: fullName.isEmpty ? "FlowDay User" : fullName,
            email: email,
            avatarURL: nil,
            provider: .apple
        )

        // Persist session to Keychain
        if let data = try? JSONEncoder().encode(user) {
            keychain.save(data, for: userKey)
        }

        currentUser = user
        isAuthenticated = true
        logger.info("Apple sign-in success: \(email)")
    }

    // MARK: - Email / password (local stub — wire to REST API later)

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // TODO: Wire to Supabase REST API directly (bypassing SDK)
        // POST https://jyeasahrkguxbhemfwny.supabase.co/auth/v1/token?grant_type=password
        errorMessage = "Email sign-in coming soon — please use Sign in with Apple for now."
        logger.info("Email sign-in not yet wired to REST API")
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        errorMessage = "Email sign-up coming soon — please use Sign in with Apple for now."
        logger.info("Email sign-up not yet wired to REST API")
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let email = result.user.profile?.email else {
                errorMessage = "Could not read Google account email"
                return
            }

            let user = FDUser(
                id: UUID(),
                name: result.user.profile?.name ?? "Google User",
                email: email,
                avatarURL: result.user.profile?.imageURL(withDimension: 96)?.absoluteString,
                provider: .google
            )

            // Save to Keychain
            if let data = try? JSONEncoder().encode(user) {
                keychain.save(data, for: userKey)
            }

            currentUser = user
            isAuthenticated = true
            logger.info("Google sign-in success: \(email)")
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
            logger.error("Google sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        keychain.delete(for: userKey)
        currentUser = nil
        isAuthenticated = false
        logger.info("User signed out")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingEmail
    case encodingError
    case keychainSaveError
    case invalidCredential
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingEmail:       return "Email information is not available from authentication provider"
        case .encodingError:      return "Failed to encode user information"
        case .keychainSaveError:  return "Failed to save authentication data securely"
        case .invalidCredential:  return "Invalid authentication credential"
        case .networkError(let m): return "Network error: \(m)"
        }
    }
}
