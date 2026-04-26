// WidgetTheme.swift
// Brand colors for the widget extension (no UIColor dynamic providers needed)

import SwiftUI

enum WC {
    static let accent  = Color(red: 0.831, green: 0.443, blue: 0.231) // #D4713B
    static let red     = Color(red: 0.831, green: 0.357, blue: 0.357) // #D45B5B
    static let yellow  = Color(red: 0.831, green: 0.655, blue: 0.231) // #D4A73B
    static let blue    = Color(red: 0.357, green: 0.561, blue: 0.831) // #5B8FD4
    static let green   = Color(red: 0.357, green: 0.627, blue: 0.396) // #5BA065

    static func priorityColor(for raw: Int) -> Color {
        switch raw {
        case 1: return red
        case 2: return yellow
        case 3: return blue
        default: return Color.secondary
        }
    }

    static func priorityLabel(for raw: Int) -> String {
        switch raw {
        case 1: return "P1"
        case 2: return "P2"
        case 3: return "P3"
        default: return "P4"
        }
    }
}
