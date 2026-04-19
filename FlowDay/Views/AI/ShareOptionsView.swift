// ShareOptionsView.swift
// FlowDay
//
// Share sheet wrapper + the custom destination picker (AirDrop / Messages /
// Email / Copy Link / More) used from the Flow AI overflow menu.

import SwiftUI

struct TaskShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showActivitySheet = false
    let taskTitle: String

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Share Task")
                    .font(.fdTitle3)
                    .foregroundColor(.fdText)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.fdTextMuted)
                }
            }
            .padding()

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ShareOptionButton(icon: "airplane.circle.fill", label: "AirDrop", color: .fdBlue)
                    ShareOptionButton(icon: "message.circle.fill", label: "Messages", color: .fdGreen)
                    ShareOptionButton(icon: "envelope.circle.fill", label: "Email", color: .fdRed)
                    ShareOptionButton(icon: "link.circle.fill", label: "Copy Link", color: .fdAccent)
                }

                HStack {
                    Button(action: { showActivitySheet = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.fdPurple)

                            Text("More")
                                .font(.fdCaption)
                                .foregroundColor(.fdText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.fdSurface)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    Spacer()
                }
            }
            .padding()

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.fdBodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.fdAccent)
                    .cornerRadius(8)
            }
            .padding()
        }
        .background(Color.fdBackground)
        .sheet(isPresented: $showActivitySheet) {
            TaskShareSheet(items: [taskTitle])
        }
    }
}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(label)
                .font(.fdCaption)
                .foregroundColor(.fdText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.fdSurface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
