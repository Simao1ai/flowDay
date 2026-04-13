// FlowDay
// AuthManager.swift
// Production-ready authentication manager supporting Sign in with Apple, Google Sign-In, and email.

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

    enum CodingKeys: String, CodingKey {
        case id, name, email, avatarURL, provider
    }
}

// MARK: - AuthManager
// Uses KeychainHelper from KeychainHelper.swift for secure storage

@Observable
final class AuthManager: NSObject {
    // MARK: - Published Properties

    var isAuthenticated: Bool = false
    var currentUser: FDUser?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.flowday.auth", category: "AuthManager")
    private let keychain = KeychainHelper.shared
    private let userKey = "com.flowday.auth.user"
    private let tokenKey = "com.flowday.auth.token"

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Restore authentication session from Keychain (call on app launch)
    func restoreSession() {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard let userJSON = keychain.readString(for: userKey) else {
            logger.debug("No stored session found in Keychain")
            isAuthenticated = false
            currentUser = nil
            return
        }

        do {
            let decoder = JSONDecoder()
            currentUser = try decoder.decode(FDUser.self, from: userJSON.data(using: .utf8)!)
            isAuthenticated = true
            logger.info("Session restored for user: \(currentUser?.email ?? "unknown")")
        } catch {
            logger.error("Failed to decode stored user: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
            keychain.delete(for: userKey)
        }
    }

    /// Sign in with Apple
    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid Apple ID credential"
            logger.error("Failed to cast to ASAuthorizationAppleIDCredential")
            return
        }

        do {
            let user = try createUserFromAppleCredential(appleIDCredential)
            try saveSession(user: user, token: appleIDCredential.identityToken ?? Data())
            currentUser = user
            isAuthenticated = true
            logger.info("Successfully signed in with Apple: \(user.email)")
        } catch {
            errorMessage = "Failed to sign in with Apple: \(error.localizedDescription)"
            logger.error("Apple sign-in error: \(error.localizedDescription)")
        }
    }

    /// Sign in with Google
    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

            let user = try createUserFromGoogleSignInResult(result)

            // Get ID token for backend validation
            let idToken = result.user.idToken?.tokenString ?? ""
            try saveSession(user: user, token: idToken.data(using: .utf8) ?? Data())

            currentUser = user
            isAuthenticated = true
            logger.info("Successfully signed in with Google: \(user.email)")
        } catch {
            errorMessage = "Failed to sign in with Google: \(error.localizedDescription)"
            logger.error("Google sign-in error: \(error.localizedDescription)")
        }
    }

    /// Email/password sign in (stub for future implementation)
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // TODO: Implement email/password authentication with backend API
        errorMessage = "Email sign-in not yet implemented"
        logger.warning("Email sign-in attempted but not implemented")
    }

    /// Sign out current user
    func signOut() {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Sign out from Google if applicable
        GIDSignIn.sharedInstance.signOut()

        // Clear keychain
        keychain.delete(for: userKey)
        keychain.delete(for: tokenKey)

        currentUser = nil
        isAuthenticated = false

        logger.info("User signed out successfully")
    }

    // MARK: - Private Helper Methods

    private func createUserFromAppleCredential(_ credential: ASAuthorizationAppleIDCredential) throws -> FDUser {
        guard let email = credential.email else {
            throw AuthError.missingEmail
        }

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return FDUser(
            id: UUID(uuidString: credential.user) ?? UUID(),
            name: name.isEmpty ? "Apple User" : name,
            email: email,
            avatarURL: nil,
            provider: .apple
        )
    }

    private func createUserFromGoogleSignInResult(_ result: GIDSignInResult) throws -> FDUser {
        guard let email = result.user.profile?.email else {
            throw AuthError.missingEmail
        }

        let name = result.user.profile?.name ?? "Google User"
        let avatarURL = result.user.profile?.imageURL?.absoluteString

        return FDUser(
            id: UUID(),
            name: name,
            email: email,
            avatarURL: avatarURL,
            provider: .google
        )
    }

    private func saveSession(user: FDUser, token: Data) throws {
        let encoder = JSONEncoder()
        let userData = try encoder.encode(user)
        guard let userJSON = String(data: userData, encoding: .utf8) else {
            throw AuthError.encodingError
        }

        keychain.saveString(userJSON, for: userKey)

        let tokenString = token.base64EncodedString()
        keychain.saveString(tokenString, for: tokenKey)
    }
}

// MARK: - Error Types

enum AuthError: LocalizedError {
    case missingEmail
    case encodingError
    case keychainSaveError
    case invalidCredential
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingEmail:
            return "Email information is not available from authentication provider"
        case .encodingError:
            return "Failed to encode user information"
        case .keychainSaveError:
            return "Failed to save authentication data securely"
        case .invalidCredential:
            return "Invalid authentication credential"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
