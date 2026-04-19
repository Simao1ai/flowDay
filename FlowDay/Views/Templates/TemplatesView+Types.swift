// TemplatesView+Types.swift
// FlowDay
//
// Shared types for the template picker — the tab enum and the template
// description struct. Kept separate so the catalog and the view code can
// both import them without creating a dependency cycle.

import SwiftUI

enum TemplateTab: CaseIterable {
    case featured, industries, personal, productivity, aiGenerate

    var title: String {
        switch self {
        case .featured: return "Featured"
        case .industries: return "Industries"
        case .personal: return "Life & Personal"
        case .productivity: return "Methods"
        case .aiGenerate: return "AI Generate"
        }
    }

    var icon: String {
        switch self {
        case .featured: return "sparkles"
        case .industries: return "building.2"
        case .personal: return "heart"
        case .productivity: return "brain.head.profile"
        case .aiGenerate: return "wand.and.stars"
        }
    }
}

struct TemplateItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let category: String
    let projects: Int
    let labels: Int
    let filters: Int
}
