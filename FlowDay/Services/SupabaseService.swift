// SupabaseService.swift
// FlowDay
//
// DISABLED: Supabase Swift SDK crashes with SIGABRT on iOS 26.x.
// All sync methods are no-ops. Will be replaced with direct REST API calls.

import Foundation

// MARK: - SupabaseService (stubbed out)

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    // All methods are no-ops until REST API replacement is built

    func syncTask(_ task: FDTask) async {}
    func recordCompletion(task: FDTask, energyLevel: EnergyLevel?) async {}
    func syncProject(_ project: FDProject) async {}
    func syncAll(tasks: [FDTask], projects: [FDProject]) async {}

    func saveTemplate(
        name: String, description: String, icon: String,
        colorHex: String, prompt: String, tasks: [[String: Any]]
    ) async {}

    func currentAccessToken() async throws -> String {
        return FlowDayConfig.supabaseAnonKey
    }
}
