// SelectionState.swift
// FlowDay
//
// Per-screen multi-select controller. Views that opt into batch operations
// hold a @State SelectionState and pass it to TaskRowView. When `isActive`
// is true, taps toggle membership in `selectedIDs` instead of opening the
// task — matching iOS's native multi-select behavior.

import SwiftUI

@Observable
final class SelectionState {
    var isActive: Bool = false
    var selectedIDs: Set<UUID> = []

    var count: Int { selectedIDs.count }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func contains(_ id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

    func enter(initial id: UUID? = nil) {
        isActive = true
        if let id { selectedIDs = [id] }
    }

    func exit() {
        isActive = false
        selectedIDs.removeAll()
    }
}
