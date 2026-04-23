// EmailToTaskView.swift
// FlowDay — Paste email text and AI parses it into a task

import SwiftUI
import SwiftData

// MARK: - Parsed Task Model

private struct ParsedEmailTask {
    var title: String
    var priority: TaskPriority
    var dueDate: Date?
    var estimatedMinutes: Int?
    var notes: String
    var labels: [String]
}

// MARK: - View

struct EmailToTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var emailText = ""
    @State private var isParsing = false
    @State private var parsedTask: ParsedEmailTask? = nil
    @State private var parseError: String? = nil
    @State private var taskAdded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    shareSheetCard
                    pasteSection

                    if isParsing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Parsing email…")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = parseError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.fdRed)
                            Text(error)
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.fdRedLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let task = parsedTask, !taskAdded {
                        parsedTaskCard(task)
                    }

                    if taskAdded {
                        successCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Email to Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdText)
                }
            }
        }
    }

    // MARK: - Share Sheet Info Card

    private var shareSheetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdAccent)
                Text("iOS Share Sheet")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("In iOS Mail, tap the share icon on any email and choose FlowDay — the app will instantly parse it into a task without copy-pasting.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
            Text("Or paste email text below for manual import.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fdBorder, lineWidth: 1))
    }

    // MARK: - Paste Section

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste Email Text")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if emailText.isEmpty {
                            Text("Paste the email body here…")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdTextMuted)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $emailText)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 140)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider()

                    Button {
                        Task { await parseEmail() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Parse with AI")
                                .font(.fdBodySemibold)
                        }
                        .foregroundStyle(canParse ? Color.fdAccent : Color.fdTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .disabled(!canParse || isParsing)
                }
            }
        }
    }

    // MARK: - Parsed Task Card

    private func parsedTaskCard(_ task: ParsedEmailTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parsed Task")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.fdBodySemibold)
                                .foregroundStyle(Color.fdText)
                            if !task.notes.isEmpty {
                                Text(task.notes)
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextSecondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(16)

                    if task.dueDate != nil || task.estimatedMinutes != nil {
                        Divider().padding(.leading, 38)

                        HStack(spacing: 16) {
                            if let due = task.dueDate {
                                Label(
                                    due.formatted(.dateTime.month(.abbreviated).day()),
                                    systemImage: "calendar"
                                )
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextSecondary)
                            }
                            if let mins = task.estimatedMinutes {
                                Label("\(mins)m", systemImage: "clock")
                                    .font(.fdCaption)
                                    .foregroundStyle(Color.fdTextSecondary)
                            }
                            Spacer()
                            Text(task.priority.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(task.priority.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(task.priority.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    Divider()

                    Button {
                        addTask(task)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add to FlowDay")
                                .font(.fdBodySemibold)
                        }
                        .foregroundStyle(Color.fdAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    // MARK: - Success Card

    private var successCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.fdGreen)
            Text("Task Added!")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Button {
                emailText = ""
                parsedTask = nil
                parseError = nil
                taskAdded = false
            } label: {
                Text("Parse Another Email")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var canParse: Bool {
        !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func parseEmail() async {
        parseError = nil
        parsedTask = nil
        isParsing = true
        defer { isParsing = false }

        let message = LLMMessage(role: .user, content: emailText)
        do {
            let response = try await ClaudeClient.shared.chat(
                feature: .emailToTask,
                messages: [message]
            )
            parsedTask = try decodeResponse(response)
        } catch {
            parseError = "Couldn't parse this email. Check your connection and try again."
        }
    }

    private func decodeResponse(_ text: String) throws -> ParsedEmailTask {
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: "\n")
            json = lines.dropFirst().dropLast()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "EmailToTask", code: -1, userInfo: nil)
        }

        let title = obj["title"] as? String ?? "Task from Email"
        let priorityInt = obj["priority"] as? Int ?? 3
        let priority = TaskPriority(rawValue: priorityInt) ?? .medium
        let notes = obj["notes"] as? String ?? ""
        let estimatedMinutes = obj["estimatedMinutes"] as? Int
        let labels = obj["labels"] as? [String] ?? []

        var dueDate: Date? = nil
        if let ds = obj["dueDate"] as? String, ds != "null", !ds.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            dueDate = fmt.date(from: ds)
        }

        return ParsedEmailTask(
            title: title,
            priority: priority,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            notes: notes,
            labels: labels
        )
    }

    private func addTask(_ task: ParsedEmailTask) {
        let fdTask = FDTask(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            estimatedMinutes: task.estimatedMinutes,
            priority: task.priority,
            labels: task.labels
        )
        modelContext.insert(fdTask)
        taskAdded = true
    }
}
