// FocusTimerView.swift
// FlowDay — Pomodoro Focus Timer

import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusTimerService.self) private var timerService

    var prelinkedTaskID: UUID? = nil

    @Query private var allTasksRaw: [FDTask]
    @Query private var allSessionsRaw: [FDFocusSession]

    private var openTasks: [FDTask] {
        allTasksRaw.filter { !$0.isDeleted && !$0.isCompleted }
    }

    private var todayFocusMinutes: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return allSessionsRaw
            .filter { $0.type == .focus && $0.wasCompleted && ($0.startedAt >= start) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    // Tracks the last completedSessionCount we already persisted, to avoid double-saves
    @State private var lastSavedSessionCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                phaseBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    ringSection
                    Spacer(minLength: 20)
                    sessionDots
                    Spacer(minLength: 32)
                    controls
                    Spacer(minLength: 24)
                    taskPickerRow
                    Spacer(minLength: 24)
                    statsRow
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 28)
            }
            .navigationTitle(phaseLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { handleClose() }
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextSecondary)
                }
                if timerService.phase != .idle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stop") { timerService.stop() }
                            .font(.fdBody)
                            .foregroundStyle(Color.fdRed)
                    }
                }
            }
            .onAppear {
                lastSavedSessionCount = timerService.completedSessionCount
                if let id = prelinkedTaskID, timerService.phase == .idle {
                    timerService.linkedTaskID = id
                }
            }
            .onChange(of: timerService.completedSessionCount) { _, newCount in
                if newCount > lastSavedSessionCount {
                    saveCompletedSession()
                    lastSavedSessionCount = newCount
                }
            }
        }
    }

    // MARK: - Ring

    private var ringSection: some View {
        ZStack {
            // Track circle
            Circle()
                .stroke(Color.fdBorder.opacity(0.5), lineWidth: 16)
                .frame(width: 240, height: 240)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 6) {
                Text(timeString)
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.fdText)
                    .monospacedDigit()

                Text(phaseLabel)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
    }

    private var progress: Double {
        guard timerService.currentPhaseTotalSeconds > 0 else { return 0 }
        return Double(timerService.secondsRemaining) / Double(timerService.currentPhaseTotalSeconds)
    }

    private var ringGradient: LinearGradient {
        isWorkPhase
            ? LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.fdBlue, Color(hex: "4DD9FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var phaseBackground: some View {
        LinearGradient(
            colors: isWorkPhase
                ? [Color.fdAccent.opacity(0.06), Color.fdBackground]
                : [Color.fdBlue.opacity(0.06), Color.fdBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var isWorkPhase: Bool {
        if case .working = timerService.phase { return true }
        if case .paused(let r) = timerService.phase, r == .working { return true }
        return false
    }

    private var timeString: String {
        let s = timerService.phase == .idle
            ? timerService.workSeconds
            : timerService.secondsRemaining
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }

    private var phaseLabel: String {
        switch timerService.phase {
        case .idle:           return "Focus Timer"
        case .working:        return "Focus"
        case .shortBreak:     return "Short Break"
        case .longBreak:      return "Long Break"
        case .paused:         return "Paused"
        }
    }

    // MARK: - Session Dots

    private var sessionDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < timerService.completedInCycle ? Color.fdAccent : Color.fdBorder)
                    .frame(width: 10, height: 10)
                    .scaleEffect(index < timerService.completedInCycle ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: timerService.completedInCycle)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            // Primary button
            Button {
                if timerService.phase == .idle {
                    timerService.start(linkedTask: timerService.linkedTaskID)
                } else {
                    timerService.pauseResume()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: primaryButtonIcon)
                        .font(.system(size: 20, weight: .semibold))
                    Text(primaryButtonLabel)
                        .font(.fdBodySemibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(primaryButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (isWorkPhase ? Color.fdAccent : Color.fdBlue).opacity(0.35), radius: 12, y: 5)
            }

            // Skip break button
            if isBreakPhase {
                Button {
                    timerService.skipBreak()
                } label: {
                    Text("Skip Break")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var isBreakPhase: Bool {
        switch timerService.phase {
        case .shortBreak, .longBreak: return true
        case .paused(let r): return r == .shortBreak || r == .longBreak
        default: return false
        }
    }

    private var primaryButtonIcon: String {
        switch timerService.phase {
        case .idle:              return "play.fill"
        case .working, .shortBreak, .longBreak: return "pause.fill"
        case .paused:            return "play.fill"
        }
    }

    private var primaryButtonLabel: String {
        switch timerService.phase {
        case .idle:              return "Start Focus"
        case .working:           return "Pause"
        case .shortBreak:        return "Pause"
        case .longBreak:         return "Pause"
        case .paused:            return "Resume"
        }
    }

    private var primaryButtonGradient: LinearGradient {
        timerService.phase == .idle || isWorkPhase
            ? LinearGradient(colors: [Color.fdAccent, Color(hex: "FF8C42")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.fdBlue, Color(hex: "4DD9FF")], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Task Picker

    private var taskPickerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 13))
                .foregroundStyle(Color.fdTextMuted)

            if openTasks.isEmpty {
                Text("No open tasks")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            } else {
                Menu {
                    Button("None") {
                        timerService.linkedTaskID = nil
                    }
                    ForEach(openTasks) { task in
                        Button {
                            timerService.linkedTaskID = task.id
                        } label: {
                            Label(task.title, systemImage: timerService.linkedTaskID == task.id ? "checkmark" : "circle")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let id = timerService.linkedTaskID,
                           let task = openTasks.first(where: { $0.id == id }) {
                            Text(task.title)
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdText)
                                .lineLimit(1)
                        } else {
                            Text("Link to a task")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statsCell(value: "\(timerService.completedSessionCount)", label: "Sessions")
            Divider().frame(height: 28)
            statsCell(value: "\(todayFocusMinutes)m", label: "Today")
            Divider().frame(height: 28)
            let cycleProgress = timerService.completedInCycle == 0
                ? (timerService.completedSessionCount > 0 ? 4 : 0)
                : timerService.completedInCycle
            statsCell(value: "\(cycleProgress)/4", label: "Cycle")
        }
        .padding(.vertical, 14)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statsCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Session Persistence

    private func saveCompletedSession() {
        let durationMinutes = timerService.workSeconds / 60
        let session = FDFocusSession(
            durationMinutes: durationMinutes,
            type: .focus,
            taskID: timerService.linkedTaskID
        )
        session.complete()
        modelContext.insert(session)
        try? modelContext.save()
    }

    // MARK: - Close

    private func handleClose() {
        if timerService.phase != .idle {
            timerService.stop()
        }
        dismiss()
    }
}
