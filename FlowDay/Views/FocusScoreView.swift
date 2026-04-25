// FocusScoreView.swift
// FlowDay — Wave 5b
//
// Circular gauge showing today's Focus Score (0–100).
// Tapping opens WeeklyReportView.

import SwiftUI
import SwiftData

struct FocusScoreView: View {
    let scoreService: FocusScoreService
    @Binding var showWeeklyReport: Bool

    private var score: Int { scoreService.todayScore }

    private var gaugeColor: Color {
        switch scoreService.color(for: score) {
        case .excellent: return .fdGreen
        case .good:      return .fdAccent
        case .fair:      return .fdYellow
        case .low:       return .fdRed
        }
    }

    var body: some View {
        Button { showWeeklyReport = true } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Background arc
                    Circle()
                        .stroke(Color.fdBorderLight, lineWidth: 4)
                        .frame(width: 44, height: 44)

                    // Score arc
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(
                            gaugeColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(gaugeColor)
                }

                Text("Score")
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.fdBorderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
