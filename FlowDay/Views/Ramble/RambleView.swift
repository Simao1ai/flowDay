// RambleView.swift
// FlowDay
//
// Two-step voice capture flow:
//   1. Listening — fullscreen warm-amber gradient with a live waveform that
//      pulses with the spoken transcript length. Stop with the check button.
//   2. Confirmation — review/edit the parsed task list, then "Add all" to
//      commit them via TaskService.
//
// Beats Todoist's Ramble by: free, parses duration, energy hints, and
// shows you what's about to be created before saving.

import SwiftUI

struct RambleView: View {
    let taskService: TaskService?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var recognizer = SpeechRecognizer()
    @State private var step: Step = .listening
    @State private var parsedTasks: [ParsedTask] = []
    @State private var includedFlags: [Bool] = []

    enum Step { case listening, confirm }

    var body: some View {
        ZStack {
            // Warm amber/orange gradient — distinct from Todoist's red
            LinearGradient(
                colors: [
                    Color(hex: "B85C24"),
                    Color(hex: "5C2A12"),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch step {
            case .listening: listeningContent
            case .confirm:   confirmContent
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                let granted = await recognizer.requestPermission()
                if granted { recognizer.startListening() }
            }
        }
        .onDisappear { recognizer.stopListening() }
    }

    // MARK: - Listening

    private var listeningContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.tap()
                    recognizer.stopListening()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // Live transcript preview
            if !recognizer.transcribedText.isEmpty {
                Text(recognizer.transcribedText)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }

            Spacer()

            // Waveform
            HStack(spacing: 5) {
                ForEach(0..<24, id: \.self) { i in
                    RambleBar(index: i, active: recognizer.isListening)
                }
            }
            .frame(height: 50)
            .padding(.bottom, 40)

            VStack(spacing: 8) {
                Text(recognizer.isListening ? "Ramble away" : "Tap to start")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Say everything you need to get done.")
                    .font(.fdBody)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)

            HStack(spacing: 20) {
                // Pause / restart
                Button {
                    Haptics.tap()
                    if recognizer.isListening {
                        recognizer.stopListening()
                    } else {
                        recognizer.startListening()
                    }
                } label: {
                    Image(systemName: recognizer.isListening ? "pause.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }

                // Done — go to confirmation
                Button {
                    Haptics.tock()
                    recognizer.stopListening()
                    parsedTasks = RambleService.parse(recognizer.transcribedText)
                    includedFlags = Array(repeating: true, count: parsedTasks.count)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        step = .confirm
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "5C2A12"))
                        .frame(width: 76, height: 76)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                }
                .disabled(recognizer.transcribedText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(recognizer.transcribedText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Confirmation

    private var confirmContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        step = .listening
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        recognizer.startListening()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                Spacer()
                Text("Review")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if parsedTasks.isEmpty {
                emptyParseResult
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(parsedTasks.enumerated()), id: \.offset) { index, task in
                            ParsedTaskCard(
                                task: task,
                                isIncluded: includedFlags.indices.contains(index) ? includedFlags[index] : true,
                                onToggle: {
                                    Haptics.tap()
                                    if includedFlags.indices.contains(index) {
                                        includedFlags[index].toggle()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }

                addAllButton
            }
        }
    }

    private var emptyParseResult: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "ear.badge.waveform")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            Text("I didn't catch any tasks")
                .font(.fdTitle3)
                .foregroundStyle(.white)
            Text("Try again — speak clearly and pause between tasks.")
                .font(.fdBody)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                Haptics.tap()
                withAnimation { step = .listening }
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    recognizer.startListening()
                }
            } label: {
                Text("Try again")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color(hex: "5C2A12"))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }

    private var addAllButton: some View {
        let count = includedFlags.filter { $0 }.count
        return VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)

            Button {
                guard let taskService else { return }
                Haptics.success()
                for (index, parsed) in parsedTasks.enumerated() {
                    guard includedFlags.indices.contains(index), includedFlags[index] else { continue }
                    taskService.createTask(
                        title: parsed.title,
                        priority: parsed.priority,
                        dueDate: parsed.dueDate,
                        scheduledTime: parsed.scheduledTime,
                        estimatedMinutes: parsed.estimatedMinutes,
                        labels: parsed.labels,
                        recurrenceRule: parsed.recurrenceRule
                    )
                }
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(count == 1 ? "Add task" : "Add \(count) tasks")
                        .font(.fdBodySemibold)
                }
                .foregroundStyle(Color(hex: "5C2A12"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            }
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(.black.opacity(0.55))
        }
    }
}

// MARK: - Waveform Bar

private struct RambleBar: View {
    let index: Int
    let active: Bool
    @State private var height: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(.white)
            .frame(width: 4, height: height)
            .onAppear { regenerate() }
            .onChange(of: active) { _, isActive in
                if isActive { regenerate() } else { height = 8 }
            }
    }

    private func regenerate() {
        withAnimation(
            .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.04)
        ) {
            height = active ? CGFloat.random(in: 14...46) : 8
        }
    }
}

// MARK: - Parsed Task Card

private struct ParsedTaskCard: View {
    let task: ParsedTask
    let isIncluded: Bool
    let onToggle: () -> Void

    private var priorityColor: Color { task.priority.color }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isIncluded ? .white : .white.opacity(0.4))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .strikethrough(!isIncluded, color: .white.opacity(0.5))
                        .opacity(isIncluded ? 1 : 0.55)

                    if !chipModels.isEmpty {
                        FlowingChips(chips: chipModels)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(.white.opacity(isIncluded ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(isIncluded ? 0.18 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chipModels: [ChipModel] {
        var chips: [ChipModel] = []
        if task.priority != .none {
            chips.append(.init(icon: "flag.fill", text: task.priority.label, tint: priorityColor))
        }
        if let project = task.projectName {
            chips.append(.init(icon: "folder.fill", text: project, tint: .fdAccent))
        }
        if let due = task.dueDate {
            chips.append(.init(icon: "calendar", text: due.formatted(.dateTime.month(.abbreviated).day()), tint: .fdBlue))
        }
        if let time = task.scheduledTime {
            chips.append(.init(icon: "clock", text: time.formatted(.dateTime.hour().minute()), tint: .fdBlue))
        }
        if let mins = task.estimatedMinutes {
            chips.append(.init(icon: "hourglass", text: "\(mins)m", tint: .fdYellow))
        }
        for label in task.labels {
            chips.append(.init(icon: "tag.fill", text: label, tint: .fdPurple))
        }
        if task.recurrenceRule != nil {
            chips.append(.init(icon: "arrow.clockwise", text: "recurring", tint: .fdGreen))
        }
        return chips
    }
}

private struct ChipModel: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let tint: Color
}

private struct FlowingChips: View {
    let chips: [ChipModel]

    var body: some View {
        // Flexible row that wraps — uses iOS 16+ Layout via standard HStack
        // with FlowLayout-equivalent through ViewThatFits + chunking. Kept
        // simple here: a single HStack that allows truncation on overflow.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips) { chip in
                    HStack(spacing: 4) {
                        Image(systemName: chip.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(chip.text)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(chip.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(chip.tint.opacity(0.18))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
