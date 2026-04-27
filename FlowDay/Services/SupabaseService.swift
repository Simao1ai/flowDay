// SupabaseService.swift
// FlowDay
//
// REST-based Supabase data layer. Bypasses the Supabase Swift SDK
// (which crashes with SIGABRT on iOS 26.x) and uses URLSession directly.
//
// Design: local-first. SwiftData is the source of truth; Supabase sync
// fires asynchronously and fails silently if offline or unauthenticated.

import Foundation
import FirebaseCrashlytics

// MARK: - SupabaseService

final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    private let baseURL: String
    private let anonKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        self.baseURL = FlowDayConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.anonKey = FlowDayConfig.supabaseAnonKey
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Auth (REST)

    /// Sign in with Apple ID token → returns Supabase session JWT
    func signInWithAppleToken(_ idToken: String) async throws -> SupabaseSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=id_token")!
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode([
            "provider": "apple",
            "id_token": idToken
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return try decoder.decode(SupabaseSession.self, from: data)
    }

    /// Sign in with email + password → returns Supabase session JWT
    func signInWithEmail(_ email: String, password: String) async throws -> SupabaseSession {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode([
            "email": email,
            "password": password
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return try decoder.decode(SupabaseSession.self, from: data)
    }

    /// Sign up with email + password
    func signUpWithEmail(_ email: String, password: String, name: String) async throws -> SupabaseSignUpResponse {
        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(SignUpBody(email: email, password: password, data: ["name": name]))
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response)
        return try decoder.decode(SupabaseSignUpResponse.self, from: data)
    }

    // MARK: - Data Sync (REST)

    /// Upsert a task row. Fire-and-forget from TaskService.
    func syncTask(_ task: FDTask) async {
        guard let jwt = currentJWT else { return }
        SyncStatusService.begin()
        do {
            let row = TaskRow.from(task, userId: currentUserId ?? "")
            let url = URL(string: "\(baseURL)/rest/v1/tasks")!
            var request = makeAuthenticatedRequest(url: url, method: "POST", jwt: jwt)
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.setValue("id", forHTTPHeaderField: "on_conflict")
            request.httpBody = try encoder.encode(row)
            let (_, response) = try await URLSession.shared.data(for: request)
            try checkHTTPStatus(response)
            SyncStatusService.end(success: true)
        } catch {
            CrashReporter.record(error, context: "SupabaseService.syncTask")
            #if DEBUG
            print("[SupabaseService] syncTask failed: \(error.localizedDescription)")
            #endif
            SyncStatusService.end(success: false, message: error.localizedDescription)
        }
    }

    /// Record a task completion event.
    func recordCompletion(task: FDTask, energyLevel: EnergyLevel?) async {
        guard let jwt = currentJWT, let userId = currentUserId else { return }
        do {
            let row = CompletionRow(
                userId: userId,
                taskId: task.id.uuidString,
                taskTitle: task.title,
                completedAt: task.completedAt ?? .now,
                energyLevel: energyLevel?.rawValue,
                projectId: task.project?.id.uuidString
            )
            let url = URL(string: "\(baseURL)/rest/v1/task_completions")!
            var request = makeAuthenticatedRequest(url: url, method: "POST", jwt: jwt)
            request.httpBody = try encoder.encode(row)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            CrashReporter.record(error, context: "SupabaseService.recordCompletion")
            #if DEBUG
            print("[SupabaseService] recordCompletion failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Upsert a project row.
    func syncProject(_ project: FDProject) async {
        guard let jwt = currentJWT, let userId = currentUserId else { return }
        SyncStatusService.begin()
        do {
            let row = ProjectRow.from(project, userId: userId)
            let url = URL(string: "\(baseURL)/rest/v1/projects")!
            var request = makeAuthenticatedRequest(url: url, method: "POST", jwt: jwt)
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.setValue("id", forHTTPHeaderField: "on_conflict")
            request.httpBody = try encoder.encode(row)
            let (_, response) = try await URLSession.shared.data(for: request)
            try checkHTTPStatus(response)
            SyncStatusService.end(success: true)
        } catch {
            CrashReporter.record(error, context: "SupabaseService.syncProject")
            #if DEBUG
            print("[SupabaseService] syncProject failed: \(error.localizedDescription)")
            #endif
            SyncStatusService.end(success: false, message: error.localizedDescription)
        }
    }

    /// Batch sync on launch.
    func syncAll(tasks: [FDTask], projects: [FDProject]) async {
        for project in projects { await syncProject(project) }
        for task in tasks { await syncTask(task) }
        #if DEBUG
        print("[SupabaseService] syncAll complete: \(tasks.count) tasks, \(projects.count) projects")
        #endif
    }

    /// Save a template.
    func saveTemplate(
        name: String, description: String, icon: String,
        colorHex: String, prompt: String, tasks: [[String: Any]]
    ) async {
        // Template save requires authenticated user — skip if no JWT
        guard let jwt = currentJWT, let userId = currentUserId else { return }
        do {
            let tasksJson = try JSONSerialization.data(withJSONObject: tasks)
            let body: [String: Any] = [
                "user_id": userId,
                "name": name,
                "description": description,
                "icon": icon,
                "color_hex": colorHex,
                "prompt": prompt,
                "tasks_json": String(data: tasksJson, encoding: .utf8) ?? "[]"
            ]
            let url = URL(string: "\(baseURL)/rest/v1/templates")!
            var request = makeAuthenticatedRequest(url: url, method: "POST", jwt: jwt)
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            CrashReporter.record(error, context: "SupabaseService.saveTemplate")
            #if DEBUG
            print("[SupabaseService] saveTemplate failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Returns the current JWT for Edge Function calls.
    func currentAccessToken() async throws -> String {
        guard let jwt = currentJWT else {
            throw SupabaseRESTError.notAuthenticated
        }
        return jwt
    }

    // MARK: - Session Management

    /// Store the Supabase session after auth
    func saveSession(_ session: SupabaseSession) {
        if let data = try? encoder.encode(session) {
            KeychainHelper.shared.save(data, for: "io.flowday.supabase.session")
        }
    }

    /// Load persisted Supabase session
    func loadSession() -> SupabaseSession? {
        guard let data = KeychainHelper.shared.read(for: "io.flowday.supabase.session"),
              let session = try? decoder.decode(SupabaseSession.self, from: data) else {
            return nil
        }
        return session
    }

    /// Clear persisted session on sign-out
    func clearSession() {
        KeychainHelper.shared.delete(for: "io.flowday.supabase.session")
    }

    // MARK: - Private Helpers

    private var currentJWT: String? {
        loadSession()?.accessToken
    }

    private var currentUserId: String? {
        loadSession()?.user?.id
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func makeAuthenticatedRequest(url: URL, method: String, jwt: String) -> URLRequest {
        var request = makeRequest(url: url, method: method)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseRESTError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SupabaseRESTError.httpError(http.statusCode)
        }
    }
}

// MARK: - REST Models

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable {
    let id: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, email
    }
}

struct SupabaseSignUpResponse: Codable {
    let accessToken: String?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

private struct SignUpBody: Codable {
    let email: String
    let password: String
    let data: [String: String]
}

enum SupabaseRESTError: Error, LocalizedError {
    case notAuthenticated
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in to Supabase"
        case .httpError(let code): return "Supabase HTTP error: \(code)"
        case .invalidResponse: return "Invalid response from Supabase"
        }
    }
}

// MARK: - Row models for REST API

private struct TaskRow: Codable {
    let id: String
    let userId: String
    let projectId: String?
    let title: String
    let notes: String
    let startDate: Date?
    let dueDate: Date?
    let scheduledTime: Date?
    let estimatedMinutes: Int?
    let priority: Int
    let labels: [String]
    let section: String?
    let sortOrder: Int
    let isCompleted: Bool
    let completedAt: Date?
    let isDeleted: Bool
    let deletedAt: Date?
    let recurrenceRule: String?
    let aiSuggestedTime: Date?
    let cognitiveLoad: Int?
    let createdAt: Date
    let modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes, priority, labels, section
        case userId = "user_id"
        case projectId = "project_id"
        case startDate = "start_date"
        case dueDate = "due_date"
        case scheduledTime = "scheduled_time"
        case estimatedMinutes = "estimated_minutes"
        case sortOrder = "sort_order"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
        case recurrenceRule = "recurrence_rule"
        case aiSuggestedTime = "ai_suggested_time"
        case cognitiveLoad = "cognitive_load"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }

    static func from(_ task: FDTask, userId: String) -> TaskRow {
        TaskRow(
            id: task.id.uuidString,
            userId: userId,
            projectId: task.project?.id.uuidString,
            title: task.title,
            notes: task.notes,
            startDate: task.startDate,
            dueDate: task.dueDate,
            scheduledTime: task.scheduledTime,
            estimatedMinutes: task.estimatedMinutes,
            priority: task.priority.rawValue,
            labels: task.labels,
            section: task.section,
            sortOrder: task.sortOrder,
            isCompleted: task.isCompleted,
            completedAt: task.completedAt,
            isDeleted: task.isDeleted,
            deletedAt: task.deletedAt,
            recurrenceRule: task.recurrenceRule,
            aiSuggestedTime: task.aiSuggestedTime,
            cognitiveLoad: task.cognitiveLoad,
            createdAt: task.createdAt,
            modifiedAt: task.modifiedAt
        )
    }
}

private struct ProjectRow: Codable {
    let id: String
    let userId: String
    let name: String
    let colorHex: String
    let iconName: String?
    let sortOrder: Int
    let isArchived: Bool
    let isFavorite: Bool
    let sections: [String]
    let createdAt: Date
    let modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, sections
        case userId = "user_id"
        case colorHex = "color_hex"
        case iconName = "icon_name"
        case sortOrder = "sort_order"
        case isArchived = "is_archived"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }

    static func from(_ project: FDProject, userId: String) -> ProjectRow {
        ProjectRow(
            id: project.id.uuidString,
            userId: userId,
            name: project.name,
            colorHex: project.colorHex,
            iconName: project.iconName,
            sortOrder: project.sortOrder,
            isArchived: project.isArchived,
            isFavorite: project.isFavorite,
            sections: project.sections,
            createdAt: project.createdAt,
            modifiedAt: .now
        )
    }
}

private struct CompletionRow: Codable {
    let userId: String
    let taskId: String
    let taskTitle: String
    let completedAt: Date
    let energyLevel: String?
    let projectId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case taskId = "task_id"
        case taskTitle = "task_title"
        case completedAt = "completed_at"
        case energyLevel = "energy_level"
        case projectId = "project_id"
    }
}
