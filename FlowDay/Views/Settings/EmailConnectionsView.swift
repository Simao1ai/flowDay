// EmailConnectionsView.swift
// FlowDay — Email account connections settings

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Main View

struct EmailConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    @State private var showAddSheet = false
    @State private var showPasteEmail = false
    @State private var showDisconnectAlert = false
    @State private var providerToDisconnect: EmailProvider? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !emailService.connectedAccounts.isEmpty {
                        connectedSection
                    }

                    addSection

                    if let error = emailService.connectionError {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    pasteEmailSection

                    shareSheetTipCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Email Connections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FDSettingsUI.backButton { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEmailAccountSheet()
                    .environment(emailService)
            }
            .sheet(isPresented: $showPasteEmail) {
                PasteEmailSheet()
            }
            .alert("Disconnect Account", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { providerToDisconnect = nil }
                Button("Disconnect", role: .destructive) {
                    if let provider = providerToDisconnect {
                        emailService.disconnect(provider)
                    }
                    providerToDisconnect = nil
                }
            } message: {
                if let provider = providerToDisconnect {
                    Text("Disconnect \(provider.displayName)? FlowDay will no longer scan this inbox.")
                }
            }
        }
    }

    // MARK: - Connected Section

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                ForEach(Array(emailService.connectedAccounts.enumerated()), id: \.element.id) { index, account in
                    connectedRow(account: account)
                    if index < emailService.connectedAccounts.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func connectedRow(account: EmailAccount) -> some View {
        HStack(spacing: 12) {
            providerIcon(account.provider, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.provider.displayName)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Text(account.email)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            }

            Spacer()

            Button {
                providerToDisconnect = account.provider
                showDisconnectAlert = true
            } label: {
                Text("Disconnect")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.fdRedLight)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Add Section

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Email Account")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                if emailService.isConnected(.gmail) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.fdGreen)
                        Text("Gmail connected")
                            .font(.fdBody)
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                    .padding(16)
                } else {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.fdAccent)
                                .frame(width: 32, height: 32)

                            Text("Add Account")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    // MARK: - Paste Email Section

    private var pasteEmailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.fdCaptionBold)
                .textCase(.uppercase)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.leading, 4)

            FDSettingsUI.group {
                Button {
                    showPasteEmail = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.fdAccent)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Task from Email")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdText)
                            Text("Paste email content and let AI extract the task")
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Share Sheet Tip Card

    private var shareSheetTipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fdAccent)
                Text("Tip: Share from any Mail app")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdText)
            }
            Text("Open an email in Mail, Gmail, or any email app — tap Share → FlowDay to instantly create a task from it.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fdBorder, lineWidth: 1)
        )
    }

    // MARK: - Provider Icon

    private func providerIcon(_ provider: EmailProvider, size: CGFloat) -> some View {
        Group {
            switch provider {
            case .gmail:
                Text("G")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .outlook:
                Image(systemName: "envelope.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(Color(hex: provider.brandHex))
        )
    }
}

// MARK: - Add Email Account Sheet

struct AddEmailAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EmailAccountService.self) private var emailService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Gmail — active
                    if !emailService.isConnected(.gmail) {
                        gmailButton
                    }

                    // Outlook — coming soon
                    outlookComingSoonRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdText)
                }
            }
        }
    }

    // MARK: - Gmail Button

    private var gmailButton: some View {
        Button {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            Task {
                let success = await emailService.connectGmail(presenting: rootVC)
                if success { await MainActor.run { dismiss() } }
            }
        } label: {
            HStack(spacing: 16) {
                providerIcon(.gmail)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gmail")
                        .font(.fdBodySemibold)
                        .foregroundStyle(Color.fdText)
                    Text("Sign in with Google")
                        .font(.fdCaption)
                        .foregroundStyle(Color.fdTextMuted)
                }

                Spacer()

                if emailService.isConnecting == .gmail {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
            .padding(16)
            .background(Color.fdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
        .disabled(emailService.isConnecting != nil)
    }

    // MARK: - Outlook Coming Soon Row

    private var outlookComingSoonRow: some View {
        HStack(spacing: 16) {
            providerIcon(.outlook)
                .opacity(0.45)

            VStack(alignment: .leading, spacing: 2) {
                Text("Outlook")
                    .font(.fdBodySemibold)
                    .foregroundStyle(Color.fdTextMuted)
                Text("Sign in with Microsoft")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted.opacity(0.6))
            }

            Spacer()

            Text("Coming Soon")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.fdSurfaceHover)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.fdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .opacity(0.7)
    }

    private func providerIcon(_ provider: EmailProvider) -> some View {
        Group {
            switch provider {
            case .gmail:
                Text("G")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            case .outlook:
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: provider.brandHex))
        )
    }
}

// MARK: - Paste Email Sheet

struct PasteEmailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var emailText = ""
    @State private var isParsing = false
    @State private var parseError: String? = nil
    @State private var parsedTask: ParsedEmailTask? = nil
    @State private var taskAdded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let parsed = parsedTask {
                        parsedResultSection(parsed)
                    } else {
                        pasteInputSection
                    }

                    if let error = parseError {
                        Text(error)
                            .font(.fdCaption)
                            .foregroundStyle(Color.fdRed)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("Create Task from Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdText)
                }
                if parsedTask != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            parsedTask = nil
                            parseError = nil
                        }
                        .foregroundStyle(Color.fdAccent)
                    }
                }
            }
        }
    }

    // MARK: - Paste Input

    private var pasteInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste Email Content")
                    .font(.fdCaptionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.leading, 4)

                TextEditor(text: $emailText)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.fdBorder, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if emailText.isEmpty {
                            Text("Paste email text here…")
                                .font(.fdBody)
                                .foregroundStyle(Color.fdTextMuted)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            }

            parseButton
        }
    }

    private var parseButton: some View {
        Button {
            parseEmail()
        } label: {
            HStack(spacing: 8) {
                if isParsing {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                }
                Text(isParsing ? "Parsing…" : "Parse")
                    .font(.fdBodySemibold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canParse ? Color.fdAccent : Color.fdSurfaceHover)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canParse || isParsing)
    }

    private var canParse: Bool {
        !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Parsed Result

    private func parsedResultSection(_ parsed: ParsedEmailTask) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Extracted Task")
                    .font(.fdCaptionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fdTextMuted)
                    .padding(.leading, 4)

                FDSettingsUI.group {
                    VStack(spacing: 0) {
                        resultRow(label: "Title", value: parsed.title)

                        Divider().padding(.leading, 16)

                        resultRow(
                            label: "Due Date",
                            value: parsed.dueDate.map {
                                $0.formatted(date: .abbreviated, time: .omitted)
                            } ?? "Not mentioned"
                        )

                        Divider().padding(.leading, 16)

                        resultRow(label: "Priority", value: parsed.priority.label)
                    }
                }
            }

            addTaskButton(parsed)
        }
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.fdBody)
                .foregroundStyle(Color.fdText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func addTaskButton(_ parsed: ParsedEmailTask) -> some View {
        Button {
            createTask(from: parsed)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: taskAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 16))
                Text(taskAdded ? "Task Added!" : "Add Task")
                    .font(.fdBodySemibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(taskAdded ? Color.fdGreen : Color.fdAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(taskAdded)
        .animation(.easeInOut(duration: 0.2), value: taskAdded)
    }

    // MARK: - Actions

    private func parseEmail() {
        let text = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isParsing = true
        parseError = nil

        Task {
            do {
                let prompt = """
                Extract an actionable task from this email. Return JSON only, no other text:
                {"title": "...", "dueDate": "YYYY-MM-DD or null", "priority": 1}

                Priority: 1=urgent, 2=high, 3=medium, 4=none.

                Email:
                \(text)
                """

                let response = try await ClaudeClient.shared.chat(
                    feature: .flowAI,
                    messages: [LLMMessage(role: .user, content: prompt)],
                    temperature: 0.2,
                    maxTokens: 256
                )

                let parsed = try parseAIResponse(response)

                await MainActor.run {
                    parsedTask = parsed
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    parseError = "Couldn't parse email: \(error.localizedDescription)"
                    isParsing = false
                }
            }
        }
    }

    private func parseAIResponse(_ raw: String) throws -> ParsedEmailTask {
        // Extract the JSON object from the response (AI may wrap it in prose or code fences)
        let jsonString: String
        if let start = raw.range(of: "{"), let end = raw.range(of: "}", options: .backwards) {
            jsonString = String(raw[start.lowerBound...end.upperBound])
        } else {
            throw ParseError.noJSON
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        let title = json["title"] as? String ?? "Task from email"

        var dueDate: Date? = nil
        if let dateStr = json["dueDate"] as? String, dateStr != "null", !dateStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            dueDate = formatter.date(from: dateStr)
        }

        let priorityRaw = json["priority"] as? Int ?? 4
        let priority: TaskPriority
        switch priorityRaw {
        case 1: priority = .urgent
        case 2: priority = .high
        case 3: priority = .medium
        default: priority = .none
        }

        return ParsedEmailTask(title: title, dueDate: dueDate, priority: priority)
    }

    private func createTask(from parsed: ParsedEmailTask) {
        let task = FDTask(
            title: parsed.title,
            dueDate: parsed.dueDate,
            priority: parsed.priority
        )
        modelContext.insert(task)
        try? modelContext.save()
        Task { await SupabaseService.shared.syncTask(task) }

        withAnimation { taskAdded = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private enum ParseError: Error {
        case noJSON
        case invalidJSON
    }
}

// MARK: - Parsed Email Task

struct ParsedEmailTask {
    var title: String
    var dueDate: Date?
    var priority: TaskPriority
}
