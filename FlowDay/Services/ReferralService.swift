// ReferralService.swift
// FlowDay — Per-user referral code + tracking via Supabase REST.
//
// On first launch after sign-in we reserve a unique code, persisted both in
// Supabase (`user_referral_codes`) and locally (UserDefaults for offline
// access). Outbound invites are recorded in `referrals`; the trigger in
// referrals.sql flips them to `completed` when the referred user signs up.

import Foundation
import Observation
import Security

struct Referral: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let referrerId: String
    let referredEmail: String?
    let referredUserId: String?
    let code: String
    let status: String
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case referrerId      = "referrer_id"
        case referredEmail   = "referred_email"
        case referredUserId  = "referred_user_id"
        case code, status
        case createdAt       = "created_at"
        case completedAt     = "completed_at"
    }
}

struct ReferralStats: Sendable {
    let invited: Int
    let joined: Int
    let active: Int
}

@Observable @MainActor
final class ReferralService {

    static let shared = ReferralService()

    private(set) var code: String?
    private(set) var referrals: [Referral] = []
    var lastError: String?

    private let codeKey = "referral_code_local"

    private let baseURL: String = FlowDayConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    private let anonKey: String = FlowDayConfig.supabaseAnonKey
    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    private init() {
        code = UserDefaults.standard.string(forKey: codeKey)
    }

    // MARK: - Public surface

    var shareLink: URL? {
        guard let code else { return nil }
        return URL(string: "https://flowdayai.app/invite/\(code)")
    }

    var shareText: String {
        if let code {
            return "Try FlowDay — the AI day planner. Use my invite link: https://flowdayai.app/invite/\(code)"
        } else {
            return "Try FlowDay — the AI day planner: https://flowdayai.app"
        }
    }

    var stats: ReferralStats {
        let invited = referrals.count
        let joined = referrals.filter { $0.status == "completed" }.count
        return ReferralStats(invited: invited, joined: joined, active: joined)
    }

    /// Loads the user's code, generating + storing one if missing, and (if
    /// signed in to Supabase) pulls the list of referrals they've sent.
    ///
    /// FlowDay's primary auth path is Apple Sign-In via Keychain, with no
    /// Supabase user. We fall back to a local-only code in that case so the
    /// share link is always available; sync to Supabase happens only when a
    /// session exists.
    func bootstrap() async {
        if code == nil {
            let generated = ReferralService.generateCode()
            code = generated
            UserDefaults.standard.set(generated, forKey: codeKey)
        }

        guard let session = SupabaseService.shared.loadSession(),
              let userId = session.user?.id else {
            lastError = nil
            return
        }

        do {
            if let existing = try await fetchExistingCode(userId: userId, jwt: session.accessToken) {
                code = existing
                UserDefaults.standard.set(existing, forKey: codeKey)
            } else if let local = code {
                try await saveCode(local, userId: userId, jwt: session.accessToken)
            }
            referrals = try await fetchReferrals(userId: userId, jwt: session.accessToken)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Records an outbound invite (used when the user shares to a contact).
    /// No-op when not signed in to Supabase.
    func recordInvite(email: String?) async {
        guard let session = SupabaseService.shared.loadSession(),
              let userId = session.user?.id,
              let code else { return }
        let row: [String: Any] = [
            "referrer_id":    userId,
            "referred_email": email ?? NSNull(),
            "code":           code,
            "status":         "pending"
        ]
        let url = URL(string: "\(baseURL)/rest/v1/referrals")!
        var request = makeRequest(url: url, method: "POST", jwt: session.accessToken)
        request.httpBody = try? JSONSerialization.data(withJSONObject: row)
        let _ = try? await URLSession.shared.data(for: request)
        await refreshReferrals()
    }

    func refreshReferrals() async {
        guard let session = SupabaseService.shared.loadSession(),
              let userId = session.user?.id else { return }
        if let updated = try? await fetchReferrals(userId: userId, jwt: session.accessToken) {
            referrals = updated
        }
    }

    // MARK: - REST helpers

    private func fetchExistingCode(userId: String, jwt: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/rest/v1/user_referral_codes?user_id=eq.\(userId)&select=code")!
        var request = makeRequest(url: url, method: "GET", jwt: jwt)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        struct Row: Decodable { let code: String }
        let rows = try decoder.decode([Row].self, from: data)
        return rows.first?.code
    }

    private func saveCode(_ code: String, userId: String, jwt: String) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/user_referral_codes")!
        var request = makeRequest(url: url, method: "POST", jwt: jwt)
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "code":    code
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
    }

    private func fetchReferrals(userId: String, jwt: String) async throws -> [Referral] {
        let url = URL(string: "\(baseURL)/rest/v1/referrals?referrer_id=eq.\(userId)&order=created_at.desc")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        return try decoder.decode([Referral].self, from: data)
    }

    private func makeRequest(url: URL, method: String, jwt: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey,            forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)",    forHTTPHeaderField: "Authorization")
        return request
    }

    private func ensureOK(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Referral", code: http.statusCode)
        }
    }

    // MARK: - Code generation

    /// Crockford-style base32 (no I/L/O/U) — 8 chars ≈ 40 bits of entropy,
    /// collision risk is negligible at the user counts we expect.
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTVWXYZ23456789")

    static func generateCode(length: Int = 8) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}
