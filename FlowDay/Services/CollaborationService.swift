// CollaborationService.swift
// FlowDay — Shared projects + members + tasks via Supabase REST.
//
// Supabase SDK is bypassed (it crashes on iOS 26.x); this layer talks to the
// REST endpoints directly with URLSession. Realtime is approximated via a
// short-interval polling loop — when the user has Pro and a shared project
// open, we refresh every 8 s. A Realtime websocket implementation can swap
// in later without touching call sites.

import Foundation
import Observation

// MARK: - Domain models

struct SharedProject: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let projectId: UUID
    let ownerId: String
    let name: String
    let colorHex: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case ownerId   = "owner_id"
        case name
        case colorHex  = "color_hex"
        case createdAt = "created_at"
    }
}

enum SharedRole: String, Codable, Sendable {
    case owner
    case editor
    case viewer
}

struct SharedMember: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let sharedProjectId: UUID
    let userId: String?
    let email: String
    let role: SharedRole
    let invitedAt: Date
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sharedProjectId = "shared_project_id"
        case userId          = "user_id"
        case email
        case role
        case invitedAt       = "invited_at"
        case acceptedAt      = "accepted_at"
    }
}

struct SharedTask: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let sharedProjectId: UUID
    let createdBy: String
    let title: String
    let notes: String
    let dueDate: Date?
    let priority: Int
    let isCompleted: Bool
    let completedAt: Date?
    let completedBy: String?
    let createdAt: Date
    let modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sharedProjectId = "shared_project_id"
        case createdBy       = "created_by"
        case title
        case notes
        case dueDate         = "due_date"
        case priority
        case isCompleted     = "is_completed"
        case completedAt     = "completed_at"
        case completedBy     = "completed_by"
        case createdAt       = "created_at"
        case modifiedAt      = "modified_at"
    }
}

enum CollaborationError: LocalizedError {
    case notAuthenticated
    case http(Int)
    case invalidResponse
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in to share a project."
        case .http(let code):   "Server error (\(code))."
        case .invalidResponse:  "Unexpected response from server."
        case .invalidEmail:     "That email doesn't look right."
        }
    }
}

// MARK: - Service

@Observable @MainActor
final class CollaborationService {

    static let shared = CollaborationService()

    private(set) var projects: [SharedProject] = []
    private(set) var membersByProject: [UUID: [SharedMember]] = [:]
    private(set) var tasksByProject: [UUID: [SharedTask]] = [:]
    private(set) var pendingInvites: [SharedMember] = []

    private(set) var isLoading = false
    var lastError: String?

    private let baseURL: String = FlowDayConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    private let anonKey: String = FlowDayConfig.supabaseAnonKey
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var pollTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 8 * 1_000_000_000

    private init() {}

    // MARK: - Public API

    /// Re-fetch every shared project the current user belongs to.
    func refresh() async {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken else {
            lastError = CollaborationError.notAuthenticated.errorDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await fetchProjects(jwt: jwt)
            for project in projects {
                membersByProject[project.id] = try await fetchMembers(projectId: project.id, jwt: jwt)
                tasksByProject[project.id]   = try await fetchTasks(projectId: project.id, jwt: jwt)
            }
            pendingInvites = try await fetchPendingInvites(jwt: jwt)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Create (or upsert) a shared project tied to a local FDProject.
    func shareProject(_ project: FDProject) async throws -> SharedProject {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken,
              let userId = SupabaseService.shared.loadSession()?.user?.id else {
            throw CollaborationError.notAuthenticated
        }
        let row: [String: Any] = [
            "project_id": project.id.uuidString,
            "owner_id":   userId,
            "name":       project.name,
            "color_hex":  project.colorHex
        ]
        let url = URL(string: "\(baseURL)/rest/v1/shared_projects")!
        var request = makeRequest(url: url, method: "POST", jwt: jwt)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        let decoded = try decoder.decode([SharedProject].self, from: data)
        guard let shared = decoded.first else { throw CollaborationError.invalidResponse }
        await refresh()
        return shared
    }

    /// Invite a collaborator by email. Server-side, the row is created
    /// pending; once that user signs in their `user_id` is back-filled by
    /// `acceptInvite`.
    func invite(email: String, to projectId: UUID, role: SharedRole = .editor) async throws {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken else {
            throw CollaborationError.notAuthenticated
        }
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw CollaborationError.invalidEmail
        }
        let row: [String: Any] = [
            "shared_project_id": projectId.uuidString,
            "email": trimmed,
            "role":  role.rawValue
        ]
        let url = URL(string: "\(baseURL)/rest/v1/shared_project_members")!
        var request = makeRequest(url: url, method: "POST", jwt: jwt)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (_, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        await refresh()
    }

    /// Mark the current user's invite as accepted, attaching their user_id.
    func acceptInvite(_ invite: SharedMember) async throws {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken,
              let userId = SupabaseService.shared.loadSession()?.user?.id else {
            throw CollaborationError.notAuthenticated
        }
        let url = URL(string: "\(baseURL)/rest/v1/shared_project_members?id=eq.\(invite.id.uuidString)")!
        var request = makeRequest(url: url, method: "PATCH", jwt: jwt)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id":     userId,
            "accepted_at": ISO8601DateFormatter().string(from: .now)
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        await refresh()
    }

    /// Decline pending invite — deletes the row.
    func declineInvite(_ invite: SharedMember) async throws {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken else {
            throw CollaborationError.notAuthenticated
        }
        let url = URL(string: "\(baseURL)/rest/v1/shared_project_members?id=eq.\(invite.id.uuidString)")!
        var request = makeRequest(url: url, method: "DELETE", jwt: jwt)
        let (_, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        await refresh()
    }

    /// Add a task to a shared project. Returns the inserted row.
    func addTask(title: String, to projectId: UUID, priority: Int = 4) async throws -> SharedTask {
        guard let jwt = SupabaseService.shared.loadSession()?.accessToken,
              let userId = SupabaseService.shared.loadSession()?.user?.id else {
            throw CollaborationError.notAuthenticated
        }
        let row: [String: Any] = [
            "id":                UUID().uuidString,
            "shared_project_id": projectId.uuidString,
            "created_by":        userId,
            "title":             title,
            "priority":          priority
        ]
        let url = URL(string: "\(baseURL)/rest/v1/shared_tasks")!
        var request = makeRequest(url: url, method: "POST", jwt: jwt)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        let decoded = try decoder.decode([SharedTask].self, from: data)
        guard let task = decoded.first else { throw CollaborationError.invalidResponse }
        var current = tasksByProject[projectId] ?? []
        current.append(task)
        tasksByProject[projectId] = current
        return task
    }

    // MARK: - Realtime (polling fallback)

    /// Begin polling shared state at a fixed cadence. Safe to call repeatedly;
    /// the previous task is cancelled first.
    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: self?.pollInterval ?? 8_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - REST helpers

    private func makeRequest(url: URL, method: String, jwt: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey,            forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)",    forHTTPHeaderField: "Authorization")
        return request
    }

    private func ensureOK(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw CollaborationError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw CollaborationError.http(http.statusCode)
        }
    }

    private func fetchProjects(jwt: String) async throws -> [SharedProject] {
        let url = URL(string: "\(baseURL)/rest/v1/shared_projects?select=*&order=created_at.desc")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        return try decoder.decode([SharedProject].self, from: data)
    }

    private func fetchMembers(projectId: UUID, jwt: String) async throws -> [SharedMember] {
        let url = URL(string: "\(baseURL)/rest/v1/shared_project_members?shared_project_id=eq.\(projectId.uuidString)&select=*")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        return try decoder.decode([SharedMember].self, from: data)
    }

    private func fetchTasks(projectId: UUID, jwt: String) async throws -> [SharedTask] {
        let url = URL(string: "\(baseURL)/rest/v1/shared_tasks?shared_project_id=eq.\(projectId.uuidString)&is_deleted=eq.false&select=*&order=sort_order.asc")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        return try decoder.decode([SharedTask].self, from: data)
    }

    private func fetchPendingInvites(jwt: String) async throws -> [SharedMember] {
        guard let email = SupabaseService.shared.loadSession()?.user?.email else { return [] }
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let url = URL(string: "\(baseURL)/rest/v1/shared_project_members?email=eq.\(encoded)&accepted_at=is.null&select=*")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response)
        return try decoder.decode([SharedMember].self, from: data)
    }
}
