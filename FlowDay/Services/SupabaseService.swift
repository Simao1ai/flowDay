// SupabaseService.swift
// FlowDay
//
// Local-first Supabase data layer.
//
// Design principle:
//   SwiftData write happens synchronously (the source of truth stays local).
//   Supabase sync fires asynchronously afterwards — if it fails (offline, auth
//   error) it fails silently and will be retried the next time the app syncs.
//
// Also serves as the single place that holds the Supabase client and vends
// the active JWT to ClaudeClient for Edge Function calls.

import Foundation
import Supabase

// MARK: - Supabase row models
// These must match the column names in schema.sql exactly.

private struct TaskRow: Codable {
    var id: String
    var userId: String
    var projectId: String?
    var title: String
    var notes: String
    var startDate: Date?
    var dueDate: Date?
    var scheduledTime: Date?
    var estimatedMinutes: Int?
    var priority: Int
    var labels: [String]
    var sortOrder: Int
    var isCompleted: Bool
    var completedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var recurrenceRule: String?
    var aiSuggestedTime: Date?
    var cognitiveLoad: Int?
    var createdAt: Date
    var modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes, priority, labels
        case userId          = "user_id"
        case projectId       = "project_id"
        case startDate       = "start_date"
        case dueDate         = "due_date"
        case scheduledTime   = "scheduled_time"
        case estimatedMinutes = "estimated_minutes"
        case sortOrder       = "sort_order"
        case isCompleted     = "is_completed"
        case completedAt     = "completed_at"
        case isDeleted       = "is_deleted"
        case deletedAt       = "deleted_at"
        case recurrenceRule  = "recurrence_rule"
        case aiSuggestedTime = "ai_suggested_time"
        case cognitiveLoad   = "cognitive_load"
        case createdAt       = "created_at"
        case modifiedAt      = "modified_at"
    }
}

private struct ProjectRow: Codable {
    var id: String
    var userId: String
    var name: String
    var colorHex: String
    var iconName: String?
    var sortOrder: Int
    var isArchived: Bool
    var isFavorite: Bool
    var sections: [String]
    var createdAt: Date
    var modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, sections
        case userId     = "user_id"
        case colorHex   = "color_hex"
        case iconName   = "icon_name"
        case sortOrder  = "sort_order"
        case isArchived = "is_archived"
        case isFavorite = "is_favorite"
        case createdAt  = "created_at"
        case modifiedAt = "modified_at"
    }
}

private struct CompletionRow: Codable {
    var id: String?
    var userId: String
    var taskId: String
    var taskTitle: String
    var completedAt: Date
    var energyLevel: String?
    var projectId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case taskId      = "task_id"
        case taskTitle   = "task_title"
        case completedAt = "completed_at"
        case energyLevel = "energy_level"
        case projectId   = "project_id"
    }
}

private struct TemplateRow: Codable {
    var id: String?
    var userId: String
    var name: String
    var description: String
    var icon: String
    var colorHex: String
    var prompt: String
    var tasksJson: [[String: AnyCodable]]
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, prompt
        case userId    = "user_id"
        case colorHex  = "color_hex"
        case tasksJson = "tasks_json"
        case createdAt = "created_at"
    }
}

// AnyCodable wrapper so we can store heterogeneous task JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String:  try c.encode(v)
        case let v as Int:     try c.encode(v)
        case let v as Double:  try c.encode(v)
        case let v as Bool:    try c.encode(v)
        default:               try c.encode("")
        }
    }
}

// MARK: - SupabaseService

final class SupabaseService {
    static let shared = SupabaseService()

    // The Supabase client — initialized lazily once Config values are available.
    // `SupabaseClient` is thread-safe and meant to be a singleton.
    private(set) lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: FlowDayConfig.supabaseURL)!,
            supabaseKey: FlowDayConfig.supabaseAnonKey
        )
    }()

    private init() {}

    // MARK: - JWT accessor (used by ClaudeClient)

    /// Returns the access token for the current session.
    /// Throws `ClaudeClientError.notAuthenticated` if there is no active session.
    func currentAccessToken() async throws -> String {
        let session = try await client.auth.session
        return session.accessToken
    }

    // MARK: - Task sync

    /// Upsert a task row. Called fire-and-forget from TaskService after every local save.
    func syncTask(_ task: FDTask) async {
        guard let userId = await currentUserId() else { return }

        let row = TaskRow(
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

        do {
            try await client
                .from("tasks")
                .upsert(row, onConflict: "id")
                .execute()
        } catch {
            #if DEBUG
            print("[SupabaseService] syncTask failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Record a task completion event.
    func recordCompletion(task: FDTask, energyLevel: EnergyLevel?) async {
        guard let userId = await currentUserId() else { return }

        let row = CompletionRow(
            id: nil,
            userId: userId,
            taskId: task.id.uuidString,
            taskTitle: task.title,
            completedAt: task.completedAt ?? .now,
            energyLevel: energyLevel?.rawValue,
            projectId: task.project?.id.uuidString
        )

        do {
            try await client
                .from("task_completions")
                .insert(row)
                .execute()
        } catch {
            #if DEBUG
            print("[SupabaseService] recordCompletion failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Project sync

    func syncProject(_ project: FDProject) async {
        guard let userId = await currentUserId() else { return }

        let row = ProjectRow(
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

        do {
            try await client
                .from("projects")
                .upsert(row, onConflict: "id")
                .execute()
        } catch {
            #if DEBUG
            print("[SupabaseService] syncProject failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Template save

    func saveTemplate(
        name: String,
        description: String,
        icon: String,
        colorHex: String,
        prompt: String,
        tasks: [[String: Any]]
    ) async {
        guard let userId = await currentUserId() else { return }

        // Convert tasks to [[String: AnyCodable]]
        let encodableTasks: [[String: AnyCodable]] = tasks.map { dict in
            dict.reduce(into: [String: AnyCodable]()) { acc, kv in
                acc[kv.key] = AnyCodable(kv.value)
            }
        }

        let row = TemplateRow(
            id: nil,
            userId: userId,
            name: name,
            description: description,
            icon: icon,
            colorHex: colorHex,
            prompt: prompt,
            tasksJson: encodableTasks,
            createdAt: nil
        )

        do {
            try await client
                .from("templates")
                .insert(row)
                .execute()
        } catch {
            #if DEBUG
            print("[SupabaseService] saveTemplate failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Full sync on launch

    /// Push all local SwiftData records that have been modified since last sync.
    /// Called once after auth is restored on app launch.
    ///
    /// Sequential (not concurrent) so that SwiftData model properties are read
    /// before any suspension point within each sync call, keeping access on the
    /// calling actor. A concurrent task group would spawn child tasks on background
    /// threads that would then touch main-actor-bound SwiftData objects — unsafe.
    func syncAll(tasks: [FDTask], projects: [FDProject]) async {
        for task in tasks {
            await syncTask(task)
        }
        for project in projects {
            await syncProject(project)
        }
        #if DEBUG
        print("[SupabaseService] syncAll complete: \(tasks.count) tasks, \(projects.count) projects")
        #endif
    }

    // MARK: - Private helpers

    private func currentUserId() async -> String? {
        guard let session = try? await client.auth.session else { return nil }
        return session.user.id.uuidString
    }
}

