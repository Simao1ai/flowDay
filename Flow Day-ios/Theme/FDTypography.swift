// FDTypography.swift
// FlowDay
//
// Typography system — warm, organic feel.
// Uses system fonts for reliability with custom styling.
// You can swap in custom fonts (e.g., "Instrument Serif") later.

import SwiftUI

extension Font {
    // MARK: - Display (serif for warmth)
    static let fdTitle        = Font.system(size: 28, weight: .bold, design: .serif)
    static let fdTitle2       = Font.system(size: 22, weight: .bold, design: .serif)
    static let fdTitle3       = Font.system(size: 18, weight: .semibold, design: .serif)

    // MARK: - Body (clean sans-serif)
    static let fdBody         = Font.system(size: 15, weight: .regular, design: .default)
    static let fdBodyMedium   = Font.system(size: 15, weight: .medium, design: .default)
    static let fdBodySemibold = Font.system(size: 15, weight: .semibold, design: .default)

    // MARK: - Small
    static let fdCaption      = Font.system(size: 13, weight: .regular, design: .default)
    static let fdCaptionBold  = Font.system(size: 13, weight: .semibold, design: .default)

    // MARK: - Micro (labels, badges)
    static let fdMicro        = Font.system(size: 11, weight: .medium, design: .default)
    static let fdMicroBold    = Font.system(size: 11, weight: .bold, design: .default)

    // MARK: - Mono (timestamps, durations)
    static let fdMono         = Font.system(size: 11, weight: .medium, design: .monospaced)
}

// MARK: - View Modifier for Section Headers

struct FDSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.fdMicroBold)
            .foregroundStyle(Color.fdTextMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

extension View {
    func fdSectionHeader() -> some View {
        modifier(FDSectionHeader())
    }
}
