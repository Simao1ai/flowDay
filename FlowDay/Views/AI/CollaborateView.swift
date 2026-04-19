// CollaborateView.swift
// FlowDay
//
// Invite-collaborators mock sheet. Placeholder UI — the backend for
// collaboration is a roadmap item, but the entry point lives in the
// Flow AI overflow menu today.

import SwiftUI

struct CollaborateView: View {
    @Environment(\.dismiss) var dismiss
    @State private var emailInput: String = ""
    @State private var selectedPermission: String = "Can View"
    let projectName: String

    let collaborators = [
        ("Sarah Chen", "sarah@flowday.app"),
        ("Marcus Johnson", "marcus@company.com")
    ]

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("Invite to Project")
                        .font(.fdTitle3)
                        .foregroundColor(.fdText)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.fdTextMuted)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Invite Collaborators")
                                .font(.fdTitle3)
                                .foregroundColor(.fdText)

                            TextField("Email address", text: $emailInput)
                                .font(.fdBody)
                                .padding(12)
                                .background(Color.fdSurface)
                                .cornerRadius(8)
                                .border(Color.fdBorder, width: 1)

                            Picker("Permission", selection: $selectedPermission) {
                                Text("Can View").tag("Can View")
                                Text("Can Edit").tag("Can Edit")
                            }
                            .font(.fdBody)
                            .padding(12)
                            .background(Color.fdSurface)
                            .cornerRadius(8)

                            Button(action: {}) {
                                Text("Send Invite")
                                    .font(.fdBodySemibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.fdAccent)
                                    .cornerRadius(8)
                            }
                            .disabled(emailInput.isEmpty)
                        }
                        .padding()
                        .background(Color.fdSurface)
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Project Members")
                                .font(.fdTitle3)
                                .foregroundColor(.fdText)

                            ForEach(collaborators, id: \.1) { name, email in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.fdAccent.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(name.prefix(1)))
                                                .font(.fdBodySemibold)
                                                .foregroundColor(.fdAccent)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.fdBodySemibold)
                                            .foregroundColor(.fdText)
                                        Text(email)
                                            .font(.fdCaption)
                                            .foregroundColor(.fdTextSecondary)
                                    }

                                    Spacer()

                                    Text("Can Edit")
                                        .font(.fdCaption)
                                        .foregroundColor(.fdTextMuted)
                                }
                                .padding(12)
                                .background(Color.fdSurfaceHover)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.fdSurface)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
        }
    }
}
