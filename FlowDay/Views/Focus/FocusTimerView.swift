// FocusTimerView.swift
// FlowDay — Pomodoro focus timer UI

import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @Environment(FocusTimerService.self) private var timerService
    @Environment(\.dismiss) private var dismiss

    @Query private var allTasksRaw: [FDTask]
    @State private var showTaskPicker = false

    private var todayTasks: [FDTask] {
        allTasksRaw.filter { !$0.isDeleted && !$0.isCompleted && $0.isScheduledToday }
    }

    private var phaseColor: Color {
        switch timerService.phase {
        case .focus:      .fdAccent
        case .shortBreak: .fdGreen
        case .longBreak:  .fdBlue
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    phaseHeader
                    timerRing
                    linkedTaskRow
                    controls
                    statsRow
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.fdBackground)
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.fdCaptionBold)
                        .foregroundStyle(Color.fdAccent)
                }
            }
        }
        .sheet(isPresented: $showTaskPicker) {
            FocusTaskPickerView(
                selectedTask: timerService.linkedTask,
                onSelect: { timerService.linkedTask = $0 },
                tasks: todayTasks
            )
        }
    }

    // MARK: - Phase header

    private var phaseHeader: some View {
        VStack(spacing: 6) {
            Text(timerService.phase.rawValue)
                .font(.fdTitle2)
                .foregroundStyle(phaseColor)
                .animation(.easeInOut(duration: 0.3), value: timerService.phase)
            Text("\(timerService.focusSessionsToday) sessions completed today")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
    }

    // MARK: - Ring

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(phaseColor.opacity(0.12), lineWidth: 14)
                .frame(width: 220, height: 220)

            Circle()
                .trim(from: 0, to: timerService.progress)
                .stroke(phaseColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timerService.progress)

            VStack(spacing: 4) {
                Text(timerService.formattedTime)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundStyle(Color.fdText)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 1), value: timerService.formattedTime)

                Text(statusLabel)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdTextMuted)
                    .animation(.easeInOut, value: timerService.isRunning)
            }
        }
    }

    private var statusLabel: String {
        if timerService.isRunning { return "in progress" }
        if timerService.isActive  { return "paused" }
        return "ready"
    }

    // MARK: - Linked task row

    @ViewBuilder
    private var linkedTaskRow: some View {
        Button {
            guard !timerService.isRunning else { return }
            showTaskPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundStyle(phaseColor)

                if let task = timerService.linkedTask {
                    Text(task.title)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .lineLimit(1)
                } else {
                    Text("Link a task (optional)")
                        .font(.fdBody)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Spacer()

                if !timerService.isRunning {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fdBorderLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 20) {
            if timerService.isActive {
                Button {
                    Haptics.warning()
                    timerService.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdTextSecondary)
                        .frame(width: 56, height: 56)
                        .background(Color.fdSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.fdBorderLight, lineWidth: 1))
                }
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                if timerService.isRunning {
                    Haptics.tap()
                    timerService.pause()
                } else if timerService.isActive {
                    Haptics.tap()
                    timerService.resume()
                } else {
                    Haptics.tock()
                    timerService.start()
                }
            } label: {
                Image(systemName: timerService.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(phaseColor)
                    .clipShape(Circle())
                    .shadow(color: phaseColor.opacity(0.4), radius: 12, y: 4)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timerService.isRunning)

            Button {
                Haptics.tap()
                timerService.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fdTextSecondary)
                    .frame(width: 56, height: 56)
                    .background(Color.fdSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.fdBorderLight, lineWidth: 1))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: timerService.isActive)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(timerService.focusSessionsToday)", label: "Today")
            Divider().frame(height: 32)
            statItem(value: "\(timerService.phase.defaultMinutes)m", label: "Duration")
            Divider().frame(height: 32)
            statItem(value: nextBreakLabel, label: "Next break")
        }
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fdBorderLight, lineWidth: 1))
    }

    private var nextBreakLabel: String {
        let untilLong = 4 - (timerService.focusSessionsToday % 4)
        return untilLong == 1 ? "Long" : "\(untilLong) left"
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdText)
            Text(label)
                .font(.fdMicro)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Task Picker

private struct FocusTaskPickerView: View {
    let selectedTask: FDTask?
    let onSelect: (FDTask?) -> Void
    let tasks: [FDTask]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("No task")
                                .foregroundStyle(Color.fdTextSecondary)
                            Spacer()
                            if selectedTask == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.fdAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !tasks.isEmpty {
                    Section("Today's Tasks") {
                        ForEach(tasks) { task in
                            Button {
                                onSelect(task)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(task.title)
                                        .foregroundStyle(Color.fdText)
                                    Spacer()
                                    if selectedTask?.id == task.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.fdAccent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Link Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
