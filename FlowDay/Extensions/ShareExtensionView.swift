// ShareExtensionView.swift
// FlowDay/Extensions/ShareExtensionView.swift
//
// Parses email content into a FlowDay task via Claude AI.
// Used inline (in-app "Import from Email") and will power the Share Extension target.
//
// Share Extension wiring (to be done in Xcode):
//   1. Add a new "Share Extension" target (FlowDayShareExtension)
//   2. Add App Group entitlement (group.io.flowday.app) to both targets
//   3. Create ShareViewController : UIHostingController<ShareExtensionView>
//      - extract NSExtensionItem text in viewDidLoad, pass as initialText
//      - write the parsed task to the shared App Group UserDefaults
//   4. The main app reads from shared container on next launch and calls TaskService

import SwiftUI

// MARK: - Parsed Email Task

struct ParsedEmailTask {
    var title: String
    var dueDate: Date?
    var priority: TaskPriority
    var notes: String
}

// MARK: - View

struct ShareExtensionView: View {
    var initialText: String = ""
    var onSave: ((ParsedEmailTask) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @State private var emailText = ""
    @State private var parsedTask: ParsedEmailTask? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var savedSuccessfully = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if savedSuccessfully {
                        successCard
                    } else if let parsed = parsedTask {
                        parsedTaskCard(parsed)
                    } else {
                        inputSection
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Import from Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel?() }
                        .foregroundStyle(Color.fdText)
                }
            }
            .onAppear {
                if !initialText.isEmpty {
                    emailText = initialText
                    Task { await parseEmail() }
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Content")
                    .font(.fdCaptionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.leading, 4)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $emailText)
                        .font(.fdBody)
                        .foregroundStyle(Color.fdText)
                        .frame(minHeight: 180)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.fdBorder, lineWidth: 1)
                        )

                    if emailText.isEmpty {
                        Text("Paste email content here…")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextMuted)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
            }

            Button {
                Task { await parseEmail() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().scaleEffect(0.85).tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15))
                    }
                    Text(isLoading ? "Parsing…" : "Parse with AI")
                        .font(.fdBodySemibold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canParse ? Color.fdAccent : Color.fdSurfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canParse || isLoading)
        }
    }

    // MARK: - Parsed Task Card

    private func parsedTaskCard(_ task: ParsedEmailTask) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.fdAccent)
                    Text("Task Extracted")
                        .font(.fdCaptionBold)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Text(task.title)
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)

                if task.dueDate != nil || task.priority != .none {
                    HStack(spacing: 16) {
                        if let due = task.dueDate {
                            Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextSecondary)
                        }
                        if task.priority != .none {
                            Label(task.priority.label, systemImage: "flag.fill")
                                .font(.fdCaption)
                                .foregroundStyle(task.priority.color)
                        }
                    }
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextSecondary)
                        .lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fdBorder, lineWidth: 1)
            )

            Button {
                onSave?(task)
                withAnimation { savedSuccessfully = true }
            } label: {
                Text("Add Task")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.fdAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                withAnimation {
                    parsedTask = nil
                    errorMessage = nil
                }
            } label: {
                Text("Edit Email")
                    .font(.fdBody)
                    .foregroundStyle(Color.fdTextSecondary)
            }
        }
    }

    // MARK: - Success Card

    private var successCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.fdGreen)
            Text("Task Added")
                .font(.fdTitle3)
                .foregroundStyle(Color.fdText)
            Text("The task has been added to your inbox.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Parsing

    private var canParse: Bool {
        !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseEmail() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let trimmed = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        Parse the following email content and extract task information. \
        Return ONLY valid JSON (no markdown, no explanation) with this exact structure:
        {
          "title": "concise action-oriented task title",
          "dueDate": "YYYY-MM-DD or null",
          "priority": "urgent|high|medium|none",
          "notes": "relevant context or empty string"
        }

        Email content:
        \(trimmed)
        """

        do {
            let response = try await ClaudeClient.shared.chat(
                feature: .flowAI,
                messages: [LLMMessage(role: .user, content: prompt)],
                temperature: 0.2,
                maxTokens: 256
            )
            await MainActor.run {
                parsedTask = parseJSONResponse(response)
                isLoading = false
                if parsedTask == nil {
                    errorMessage = "Could not parse AI response. Please try again."
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func parseJSONResponse(_ response: String) -> ParsedEmailTask? {
        // Strip any markdown code fences the model might add
        let cleaned: String
        if let start = response.range(of: "{"), let end = response.range(of: "}", options: .backwards) {
            cleaned = String(response[start.lowerBound...end.upperBound])
        } else {
            cleaned = response
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let title = (json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Task"
        let notes = json["notes"] as? String ?? ""

        var dueDate: Date? = nil
        if let dateStr = json["dueDate"] as? String, dateStr != "null" {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDate = formatter.date(from: dateStr)
        }

        let priorityStr = (json["priority"] as? String)?.lowercased() ?? "none"
        let priority: TaskPriority
        switch priorityStr {
        case "urgent": priority = .urgent
        case "high":   priority = .high
        case "medium": priority = .medium
        default:       priority = .none
        }

        return ParsedEmailTask(title: title, dueDate: dueDate, priority: priority, notes: notes)
    }
}
