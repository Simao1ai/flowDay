// FlowDay
// AuthManager.swift
//
// Production-ready authentication manager.
// Sign in with Apple and email/password are wired to Supabase Auth.
// Google Sign-In is kept for future wiring but is not yet connected to Supabase.
//
// Session persistence is handled by the Supabase Swift SDK (it stores the
// refresh token in Keychain automatically). On launch, call restoreSession()
// to re-hydrate state from the SDK's persisted session.

import Foundation
import AuthenticationServices
import GoogleSignIn
import Supabase
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

@Observable
final class AuthManager: NSObject {

    // MARK: - State

    var isAuthenticated: Bool = false
    var currentUser: FDUser?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Private

    private let logger = Logger(subsystem: "com.flowday.auth", category: "AuthManager")

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - Session restore

    /// Restore auth state from the Supabase SDK's persisted session (Keychain-backed).
    /// Call once on app launch. No network round-trip if the token is still valid;
    /// the SDK silently refreshes it in the background if it has expired.
    func restoreSession() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let session = try await SupabaseService.shared.client.auth.session
                await MainActor.run {
                    currentUser = fdUser(from: session.user)
                    isAuthenticated = true
                }
                logger.info("Session restored for \(session.user.email ?? "unknown")")
            } catch {
                // No persisted session — user needs to sign in
                await MainActor.run {
                    isAuthenticated = false
                    currentUser = nil
                }
                logger.debug("No persisted Supabase session: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Sign in with Apple

    /// Call this from the SignInWithAppleButton's onCompletion handler.
    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Invalid Apple ID credential"
            logger.error("Could not extract Apple identity token")
            return
        }

        do {
            // Send the Apple ID token to Supabase — it validates it server-side
            // and returns a Supabase session backed by the user's Apple account.
            let session = try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )

            // On first sign-in, Apple provides the user's name. On subsequent
            // sign-ins the name fields are nil, so we fall back to the profile.
            let fullName = [
                credential.fullName?.givenName,
                credential.fullName?.familyName
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

            // Update the profile row if we got a name
            if !fullName.isEmpty {
                try? await SupabaseService.shared.client
                    .from("profiles")
                    .upsert([
                        "id": session.user.id.uuidString,
                        "name": fullName,
                        "email": session.user.email ?? "",
                        "provider": "apple"
                    ])
                    .execute()
            }

            currentUser = fdUser(from: session.user, overrideName: fullName.isEmpty ? nil : fullName)
            isAuthenticated = true
            logger.info("Apple sign-in success: \(session.user.email ?? "unknown")")
        } catch {
            errorMessage = "Sign in with Apple failed: \(error.localizedDescription)"
            logger.error("Apple sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Email / password

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await SupabaseService.shared.client.auth.signIn(
                email: email,
                password: password
            )
            currentUser = fdUser(from: session.user)
            isAuthenticated = true
            logger.info("Email sign-in success: \(email)")
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            logger.error("Email sign-in error: \(error.localizedDescription)")
        }
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await SupabaseService.shared.client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            // signUp returns a session immediately if email confirmation is disabled
            if let s = session.session {
                currentUser = fdUser(from: s.user, overrideName: name)
                isAuthenticated = true
            } else {
                // Email confirmation required — user must verify before session is issued
                errorMessage = "Check your email to confirm your account."
            }
            logger.info("Email sign-up success: \(email)")
        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
            logger.error("Email sign-up error: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign-In (not yet wired to Supabase)

    /// Currently authenticates with Google only — not connected to Supabase.
    /// To complete the Supabase wiring: exchange result.user.idToken for a
    /// Supabase session via signInWithIdToken(provider: .google, ...).
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

            // TODO: Wire to Supabase once Google OAuth is configured in the Supabase dashboard.
            // let idToken = result.user.idToken?.tokenString ?? ""
            // let session = try await SupabaseService.shared.client.auth.signInWithIdToken(
            //     credentials: .init(provider: .google, idToken: idToken)
            // )

            currentUser = FDUser(
                id: UUID(),
                name: result.user.profile?.name ?? "Google User",
                email: email,
                avatarURL: result.user.profile?.imageURL?.absoluteString,
                provider: .google
            )
            isAuthenticated = true
            logger.info("Google sign-in success (local only): \(email)")
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
            logger.error("Google sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign out

    func signOut() {
        Task {
            try? await SupabaseService.shared.client.auth.signOut()
        }
        currentUser = nil
        isAuthenticated = false
        logger.info("User signed out")
    }

    // MARK: - Private helpers

    private func fdUser(
        from user: Supabase.User,
        overrideName: String? = nil
    ) -> FDUser {
        let name = overrideName
            ?? user.userMetadata["name"]?.value as? String
            ?? user.email?.components(separatedBy: "@").first
            ?? "FlowDay User"

        let provider: AuthProvider
        switch user.appMetadata["provider"]?.value as? String {
        case "apple":  provider = .apple
        case "google": provider = .google
        default:       provider = .email
        }

        return FDUser(
            id: user.id,
            name: name,
            email: user.email ?? "",
            avatarURL: nil,
            provider: provider
        )
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
