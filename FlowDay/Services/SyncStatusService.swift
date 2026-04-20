// SyncStatusService.swift
// FlowDay
//
// Surfaces Supabase sync state to the UI. SupabaseService fires
// begin/finish/fail calls as it runs; the toolbar subscribes to this
// singleton so users can see whether their data made it to the cloud.

import Foundation
import SwiftUI

@Observable @MainActor
final class SyncStatusService {

    static let shared = SyncStatusService()

    enum State: Equatable {
        case idle
        case syncing
        case synced(at: Date)
        case offline
        case error(String)
    }

    var state: State = .idle

    /// Outstanding sync operations. UI shows "syncing" while > 0.
    private var inFlight: Int = 0

    private init() {}

    func beginSync() {
        inFlight += 1
        if inFlight == 1 { state = .syncing }
    }

    func endSync(success: Bool, errorMessage: String? = nil) {
        inFlight = max(0, inFlight - 1)
        guard inFlight == 0 else { return }
        if success {
            state = .synced(at: .now)
        } else if let errorMessage {
            state = .error(errorMessage)
        } else {
            state = .offline
        }
    }

    /// Hard reset — call on sign-out.
    func reset() {
        inFlight = 0
        state = .idle
    }
}

// MARK: - Non-isolated facade
// SupabaseService runs off the main actor. Use these to update state from anywhere.

extension SyncStatusService {
    nonisolated static func begin() {
        Task { @MainActor in SyncStatusService.shared.beginSync() }
    }
    nonisolated static func end(success: Bool, message: String? = nil) {
        Task { @MainActor in SyncStatusService.shared.endSync(success: success, errorMessage: message) }
    }
}
