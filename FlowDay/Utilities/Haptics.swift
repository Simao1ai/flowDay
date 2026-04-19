// Haptics.swift
// FlowDay
//
// Thin wrapper over UIKit feedback generators so haptic calls stay a one-liner.
// All generators live here to avoid re-allocating them at each call site.

import UIKit

enum Haptics {

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Tiny tap — use for small state flips (subtask check, chip select).
    static func tap() { light.impactOccurred() }

    /// A bit heftier — task completion, habit check-in.
    static func tock() { medium.impactOccurred() }

    /// Crisp click — swipe-to-delete, destructive confirm.
    static func click() { rigid.impactOccurred() }

    /// Value change — picker, segmented control, priority change.
    static func pick() { selection.selectionChanged() }

    /// Positive outcome — sync succeeded, goal met.
    static func success() { notification.notificationOccurred(.success) }

    /// Error feedback — sync failed, validation error.
    static func error() { notification.notificationOccurred(.error) }

    /// Warning feedback — about to delete, destructive prompt.
    static func warning() { notification.notificationOccurred(.warning) }
}
