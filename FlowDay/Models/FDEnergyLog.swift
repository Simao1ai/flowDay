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
        switch self { case .high: "⚡"; case .normal: "☀️"; case .low: "🌙" }
    }
    var label: String {
        switch self { case .high: "High energy"; case .normal: "Normal"; case .low: "Low energy" }
    }
    var description: String {
        switch self { case .high: "Ready for deep work"; case .normal: "Balanced day ahead"; case .low: "Go easy today" }
    }
    var maxComfortableLoad: Int {
        switch self { case .high: 5; case .normal: 3; case .low: 2 }
    }
}
