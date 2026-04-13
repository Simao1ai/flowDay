// FDEnergyLog.swift
// FlowDay — Energy-aware scheduling (no competitor does this)

import Foundation
import SwiftData

@Model
final class FDEnergyLog {
    var id: UUID
    var date: Date
    var level: EnergyLevel
    var note: String?

    init(level: EnergyLevel, date: Date = .now, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.level = level
        self.note = note
    }
}

enum EnergyLevel: String, Codable, CaseIterable {
    case high = "high"
    case normal = "normal"
    case low = "low"

    var emoji: String {
        switch self {
        case .high: return "⚡"
        case .normal: return "☀️"
        case .low: return "🌙"
        }
    }
    var label: String {
        switch self {
        case .high: return "High energy"
        case .normal: return "Normal"
        case .low: return "Low energy"
        }
    }
    var description: String {
        switch self {
        case .high: return "Ready for deep work"
        case .normal: return "Balanced day ahead"
        case .low: return "Go easy today"
        }
    }
    var maxComfortableLoad: Int {
        switch self {
        case .high: return 5
        case .normal: return 3
        case .low: return 2
        }
    }
}
