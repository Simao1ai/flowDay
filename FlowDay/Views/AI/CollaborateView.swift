// CollaborateView.swift
// FlowDay
//
// Real shared-projects UI backed by CollaborationService. Lists every
// project the signed-in user belongs to, lets the owner invite collaborators
// by email, and shows incoming invites the user can accept or decline.

import SwiftUI
import SwiftData

struct CollaborateView: View {
    @Environment(\.dismiss) var dismiss
    @State private var collab = CollaborationService.shared
    @State private var emailInput = ""
    @State private var selectedRole: SharedRole = .editor
    @State private var inviteError: String?
    @State private var selectedProject: SharedProject?
    @State private var showShareLocalProject = false
    @State private var newTaskTitle = ""

    @Query private var localProjects: [FDProject]

    /// Optional: invoked from a specific FDProject. nil = entry from menu.
    let projectName: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fdBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if !collab.pendingInvites.isEmpty {
                            pendingInvitesSection
                        }

                        sharedProjectsSection

                        if let project = selectedProject {
                            projectDetailSection(project: project)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Collaborate")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.fdTextMuted)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showShareLocalProject = true
                    } label: {
                        Label("Share Project", systemImage: "plus.circle")
                            .font(.fdCaptionBold)
                    }
                }
            }
            .task { await collab.refresh() }
            .onAppear { collab.startPolling() }
            .onDisappear { collab.stopPolling() }
            .sheet(isPresented: $showShareLocalProject) {
                ShareLocalProjectSheet(localProjects: localProjects)
            }
        }
    }

    // MARK: - Pending invites

    private var pendingInvitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pending Invites")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .textCase(.uppercase)

            ForEach(collab.pendingInvites) { invite in
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(Color.fdAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project invite")
                            .font(.fdBodySemibold)
                            .foregroundStyle(Color.fdText)
                        Text(invite.role.rawValue.capitalized)
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextSecondary)
                    }
                    Spacer()
                    Button("Accept") {
                        Task { try? await collab.acceptInvite(invite) }
                    }
                    .font(.fdCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.fdAccent)
                    .clipShape(Capsule())

                    Button("Decline") {
                        Task { try? await collab.declineInvite(invite) }
                    }
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextSecondary)
                }
                .padding(12)
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Shared projects

    private var sharedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shared Projects")
                    .font(.fdCaptionBold)
                    .foregroundStyle(Color.fdTextMuted)
                    .textCase(.uppercase)
                Spacer()
                if collab.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }

            if collab.projects.isEmpty {
                Text("Nothing shared yet. Tap “Share Project” to invite teammates.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(collab.projects) { project in
                    Button { selectedProject = project } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: project.colorHex))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name.isEmpty ? "Untitled" : project.name)
                                    .font(.fdBodySemibold)
                                    .foregroundStyle(Color.fdText)
                                Text("\(collab.membersByProject[project.id]?.count ?? 0) member(s)")
                                    .font(.fdMicro)
                                    .foregroundStyle(Color.fdTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        .padding(12)
                        .background(selectedProject?.id == project.id ? Color.fdAccentLight : Color.fdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Project detail

    private func projectDetailSection(project: SharedProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            inviteRow(project: project)
            membersList(project: project)
            tasksList(project: project)
        }
    }

    private func inviteRow(project: SharedProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite by Email")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                TextField("teammate@example.com", text: $emailInput)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker("Role", selection: $selectedRole) {
                    Text("Editor").tag(SharedRole.editor)
                    Text("Viewer").tag(SharedRole.viewer)
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Button("Invite") {
                    let email = emailInput
                    Task {
                        do {
                            try await collab.invite(email: email, to: project.id, role: selectedRole)
                            emailInput = ""
                            inviteError = nil
                        } catch {
                            inviteError = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.fdAccent)
                .disabled(emailInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let inviteError {
                Text(inviteError)
                    .font(.fdMicro)
                    .foregroundStyle(Color.fdRed)
            }
        }
    }

    private func membersList(project: SharedProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Members")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .textCase(.uppercase)

            let members = collab.membersByProject[project.id] ?? []
            if members.isEmpty {
                Text("Just you.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.fdAccent.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(member.email.prefix(1)).uppercased())
                                    .font(.fdCaptionBold)
                                    .foregroundStyle(Color.fdAccent)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.email)
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdText)
                            Text(member.acceptedAt == nil ? "Pending" : "Joined")
                                .font(.fdMicro)
                                .foregroundStyle(member.acceptedAt == nil ? Color.fdYellow : Color.fdGreen)
                        }
                        Spacer()
                        Text(member.role.rawValue.capitalized)
                            .font(.fdMicro)
                            .foregroundStyle(Color.fdTextMuted)
                    }
                    .padding(10)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func tasksList(project: SharedProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Tasks")
                .font(.fdCaptionBold)
                .foregroundStyle(Color.fdTextMuted)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                TextField("Add a task…", text: $newTaskTitle)
                    .padding(10)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .submitLabel(.done)
                    .onSubmit { addTaskAction(project: project) }

                Button {
                    addTaskAction(project: project)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.fdAccent)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            let tasks = collab.tasksByProject[project.id] ?? []
            if tasks.isEmpty {
                Text("No shared tasks yet.")
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdTextMuted)
            } else {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? Color.fdGreen : Color.fdTextMuted)
                        Text(task.title)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                            .strikethrough(task.isCompleted)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.fdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func addTaskAction(project: SharedProject) {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            _ = try? await collab.addTask(title: trimmed, to: project.id)
            await MainActor.run { newTaskTitle = "" }
        }
    }
}

// MARK: - Share local project sheet

private struct ShareLocalProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let localProjects: [FDProject]

    var body: some View {
        NavigationStack {
            List(localProjects) { project in
                Button {
                    Task {
                        _ = try? await CollaborationService.shared.shareProject(project)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .foregroundStyle(Color.fdText)
                    }
                }
            }
            .navigationTitle("Share a Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
