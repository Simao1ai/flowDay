// FlowDayWidgetsBundle.swift
// FlowDay — Widget extension entry point

import WidgetKit
import SwiftUI

@main
struct FlowDayWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodaySummaryWidget()
        NextTaskWidget()
        FocusScoreLockScreenWidget()
        FocusTimerLiveActivity()
    }
}
