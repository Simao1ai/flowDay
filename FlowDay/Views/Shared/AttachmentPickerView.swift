// AttachmentPickerView.swift
// FlowDay

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Picker sheet

struct AttachmentPickerView: View {
    let task: FDTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    AttachmentOptionRow(icon: "photo.on.rectangle", title: "Photo or Video", color: .fdBlue) {
                        showPhotoPicker = true
                    }
                    Divider().padding(.leading, 52)
                    AttachmentOptionRow(icon: "doc.badge.plus", title: "File", color: .fdGreen) {
                        showDocumentPicker = true
                    }
                }
                .background(Color.fdSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
            }
            .background(Color.fdBackground)
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.fdTextSecondary)
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedItem,
                matching: .any(of: [.images, .screenshots])
            )
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    await savePhoto(item)
                    selectedItem = nil
                    dismiss()
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    saveFile(url)
                    dismiss()
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    // MARK: - Save helpers

    private func savePhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = TaskAttachment.attachmentsDirectory.appendingPathComponent(filename)

        guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? jpegData.write(to: fileURL)

        let thumbSize = CGSize(width: 100, height: 100)
        let thumbnailData = uiImage.preparingThumbnail(of: thumbSize)?.jpegData(compressionQuality: 0.7)

        let attachment = TaskAttachment(
            filename: filename,
            type: .photo,
            localPath: filename,
            thumbnailData: thumbnailData
        )
        await MainActor.run {
            task.addAttachment(attachment)
            try? modelContext.save()
        }
    }

    private func saveFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let filename = "\(UUID().uuidString)_\(url.lastPathComponent)"
        let destURL = TaskAttachment.attachmentsDirectory.appendingPathComponent(filename)
        try? FileManager.default.copyItem(at: url, to: destURL)

        let attachment = TaskAttachment(filename: url.lastPathComponent, type: .file, localPath: filename)
        task.addAttachment(attachment)
        try? modelContext.save()
    }
}

// MARK: - Option row

private struct AttachmentOptionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.fdBody)
                    .foregroundStyle(Color.fdText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Attachment thumbnail

struct AttachmentThumbnailView: View {
    let attachment: TaskAttachment
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailBody
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.fdBorderLight, lineWidth: 1)
                )

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.fdBackground, Color.fdTextSecondary)
            }
            .offset(x: 8, y: -8)
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var thumbnailBody: some View {
        if attachment.type == .photo,
           let thumbData = attachment.thumbnailData,
           let uiImage = UIImage(data: thumbData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.fdSurface
                VStack(spacing: 4) {
                    Image(systemName: attachment.displayIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.fdAccent)
                    Text(attachment.filename)
                        .font(.system(size: 8))
                        .foregroundStyle(Color.fdTextMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - UIDocumentPickerViewController wrapper

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .image, .spreadsheet, .presentation, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
