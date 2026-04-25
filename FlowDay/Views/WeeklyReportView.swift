// WeeklyReportView.swift
// FlowDay — Wave 5b
//
// AI-generated weekly productivity report. Shows Focus Score,
// trend vs last week, breakdown by component, and an AI recommendation.

import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query private var allTasksRaw: [FDTask]
    @Query private var allHabitsRaw: [FDHabit]
    @Query private var allSessionsRaw: [FDFocusSession]

    private var tasks: [FDTask] { allTasksRaw.filter { !$0.isDeleted } }
    private var habits: [FDHabit] { allHabitsRaw.filter(\.isActive) }

    @State private var scoreService = FocusScoreService.shared
    @State private var report: WeeklyScoreReport?
    @State private var shareText: String?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if let report {
                        scoreSection(report)
                        breakdownSection(report)
                        statsSection(report)
                        aiSection
                    } else {
                        loadingView
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.fdBackground)
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if report != nil {
                        Button {
                            buildShareText()
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.fdAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let text = shareText {
                    ShareSheet(text: text)
                }
            }
            .task {
                let r = scoreService.buildWeeklyReport(tasks: tasks, focusSessions: allSessionsRaw, habits: habits)
                report = r
                await scoreService.generateRecommendation(report: r, tasks: tasks)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.fdAccent, Color.fdPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Weekly Report")
                    .font(.fdTitle3)
                    .foregroundStyle(Color.fdText)
                Text(weekRangeLabel)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
            }
        }
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        let today = Date.now
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: today))"
    }

    // MARK: - Score Section

    private func scoreSection(_ report: WeeklyScoreReport) -> some View {
        let color = gaugeColor(for: report.weekScore)
        return VStack(spacing: 16) {
            // Big score
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.fdBorderLight, lineWidth: 8)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.weekScore) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(report.weekScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text("/ 100")
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }

                // Trend
                HStack(spacing: 4) {
                    Image(systemName: report.trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(report.trend >= 0 ? Color.fdGreen : Color.fdRed)
                    Text(trendLabel(report.trend))
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private func trendLabel(_ trend: Int) -> String {
        if trend == 0 { return "Same as last week" }
        let abs = Swift.abs(trend)
        return trend > 0 ? "+\(abs) pts vs last week" : "\(abs) pts below last week"
    }

    private func gaugeColor(for score: Int) -> Color {
        switch FocusScoreService.shared.color(for: score) {
        case .excellent: return .fdGreen
        case .good:      return .fdAccent
        case .fair:      return .fdYellow
        case .low:       return .fdRed
        }
    }

    // MARK: - Breakdown

    private func breakdownSection(_ report: WeeklyScoreReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 11))
                Text("Score Breakdown")
            }
            .fdSectionHeader()

            let breakdown = scoreService.todayBreakdown
            VStack(spacing: 8) {
                breakdownRow(label: "Tasks Completed", value: breakdown.taskPoints, max: 40, color: .fdGreen)
                breakdownRow(label: "Focus Time", value: breakdown.focusPoints, max: 25, color: .fdAccent)
                breakdownRow(label: "Habits", value: breakdown.habitPoints, max: 20, color: .fdPurple)
                breakdownRow(label: "Energy Alignment", value: breakdown.energyPoints, max: 15, color: .fdYellow)
            }
            .padding(16)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
        }
    }

    private func breakdownRow(label: String, value: Int, max: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Text("\(value)/\(max)")
                    .font(.fdCaptionBold)
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.fdBorderLight)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(max), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Stats

    private func statsSection(_ report: WeeklyScoreReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 11))
                Text("This Week")
            }
            .fdSectionHeader()

            HStack(spacing: 10) {
                weekStatCard(value: "\(report.totalTasksCompleted)", label: "Tasks Done", icon: "checkmark.circle", color: .fdGreen)
                weekStatCard(value: "\(report.totalFocusMinutes)m", label: "Focus Time", icon: "timer", color: .fdAccent)
                weekStatCard(value: "\(Int(report.habitHitRate * 100))%", label: "Habit Rate", icon: "flame", color: .fdPurple)
            }
        }
    }

    private func weekStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fdBorderLight, lineWidth: 1))
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text("AI Recommendation")
            }
            .fdSectionHeader()

            if scoreService.isLoadingAI {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.fdAccent)
                    Text("Generating insight…")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let rec = scoreService.aiRecommendation {
                Text(rec)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color.fdAccentLight, Color.fdPurpleLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color.fdAccent)
            Text("Building your report…")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Share

    private func buildShareText() {
        guard let report else { return }
        var lines = [
            "📊 My FlowDay Weekly Report",
            "Focus Score: \(report.weekScore)/100 (\(trendLabel(report.trend)))",
            "Tasks completed: \(report.totalTasksCompleted)",
            "Focus time: \(report.totalFocusMinutes) min",
            "Habit hit rate: \(Int(report.habitHitRate * 100))%"
        ]
        if let rec = scoreService.aiRecommendation {
            lines.append("")
            lines.append("AI Insight: \(rec)")
        }
        shareText = lines.joined(separator: "\n")
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
