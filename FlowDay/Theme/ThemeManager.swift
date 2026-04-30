// ThemeManager.swift
// FlowDay — Active theme + helpers for color/scheme overrides.
//
// The theme name is the single source of truth, persisted in UserDefaults
// under "selected_theme". Color.fdAccent / Color.fdBackground are computed
// to read this key, so they update when the root view re-renders after a
// theme change.

import SwiftUI

@Observable @MainActor
final class ThemeManager {

    static let shared = ThemeManager()

    nonisolated static let storageKey = "selected_theme"

    /// The active theme key. Setting this writes through to UserDefaults
    /// and triggers an SwiftUI invalidation for views observing this.
    var themeID: String {
        didSet {
            guard themeID != oldValue else { return }
            UserDefaults.standard.set(themeID, forKey: ThemeManager.storageKey)
        }
    }

    private init() {
        themeID = UserDefaults.standard.string(forKey: ThemeManager.storageKey) ?? "Warm"
    }

    // MARK: - Theme definitions

    /// Returns nil to follow the system setting.
    var preferredColorScheme: ColorScheme? {
        switch themeID {
        case "Dark":          return .dark
        case "Midnight":      return .dark
        default:              return .light
        }
    }

    /// True for the OLED-black "Dark" theme — used by FDColors to flip the
    /// background and surface to pure black. UserDefaults reads are thread-safe.
    nonisolated static var isOLEDBlack: Bool {
        UserDefaults.standard.string(forKey: storageKey) == "Dark"
    }

    /// True for the cool blue palette.
    nonisolated static var isCool: Bool {
        UserDefaults.standard.string(forKey: storageKey) == "Cool"
    }

    /// Theme-specific accent color. Read by Color.fdAccent at render time.
    nonisolated static var accent: Color {
        switch UserDefaults.standard.string(forKey: storageKey) ?? "Warm" {
        case "Cool":      return Color(hex: "5B8FD4")
        case "Midnight":  return Color(hex: "8B6BBF")
        case "Moonstone": return Color(hex: "9CA3AF")
        case "Tangerine": return Color(hex: "FB923C")
        case "Dark":      return Color(hex: "FF8C42")
        default:          return Color(hex: "D4713B") // Warm / FlowDay
        }
    }
}
