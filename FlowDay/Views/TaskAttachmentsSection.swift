// TaskAttachmentsSection.swift
// FlowDay — Wave 4b
//
// Attachment panel for TaskDetailSheet: photos via PHPicker,
// files via UIDocumentPickerViewController, and plain links.

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct TaskAttachmentsSection: View {
    @Bindable var task: FDTask
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showAddLink = false
    @State private var linkURL = ""
    @State private var linkTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                Text("Attachments")
            }
            .fdSectionHeader()
            .padding(.horizontal, 20)

            // Existing attachments
            let sorted = task.attachments.sorted { $0.createdAt < $1.createdAt }
            if !sorted.isEmpty {
                VStack(spacing: 4) {
                    ForEach(sorted) { attachment in
                        attachmentRow(attachment)
                    }
                }
                .padding(.bottom, 4)
            }

            // Add-attachment buttons
            HStack(spacing: 8) {
                addButton(icon: "photo.on.rectangle", label: "Photo") {
                    showPhotoPicker = true
                }
                addButton(icon: "doc.badge.plus", label: "File") {
                    showFileImporter = true
                }
                addButton(icon: "link.badge.plus", label: "Link") {
                    showAddLink = true
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        // Photos picker
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await importPhotos(newItems) }
        }
        // File importer
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data, .text, .pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            importFile(result: result)
        }
        // Link alert
        .alert("Add Link", isPresented: $showAddLink) {
            TextField("https://…", text: $linkURL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            TextField("Title (optional)", text: $linkTitle)
            Button("Add") { saveLink() }
            Button("Cancel", role: .cancel) { resetLinkFields() }
        } message: {
            Text("Paste a URL to attach it to this task.")
        }
    }

    // MARK: - Attachment row

    private func attachmentRow(_ attachment: FDTaskAttachment) -> some View {
        HStack(spacing: 10) {
            // Thumbnail or fallback icon
            if let data = attachment.thumbnailData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.fdAccentLight)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: iconForType(attachment.type))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.fdAccent)
                    }
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.title)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1)
                if let url = attachment.urlString {
                    Text(url)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Open button
            Button {
                openAttachment(attachment)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fdAccent)
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                deleteAttachment(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Add button

    private func addButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.fdMicro)
            }
            .foregroundStyle(Color.fdAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.fdAccentLight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo import

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let attachment = FDTaskAttachment(
                type: .photo,
                title: "Photo",
                urlString: nil,
                thumbnailData: makeThumbnail(from: data)
            )

            // Store full image in Documents/Attachments/
            if let fileURL = writeToAttachmentsDir(data: data, filename: "\(attachment.id.uuidString).jpg") {
                attachment.urlString = fileURL.absoluteString
            }
            attachment.task = task
            modelContext.insert(attachment)
        }
        try? modelContext.save()
        selectedPhotoItems = []
    }

    // MARK: - File import

    private func importFile(result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }
        let filename = url.lastPathComponent
        let attachment = FDTaskAttachment(type: .file, title: filename)

        if let fileURL = writeToAttachmentsDir(data: data, filename: "\(attachment.id.uuidString)_\(filename)") {
            attachment.urlString = fileURL.absoluteString
        }
        attachment.task = task
        modelContext.insert(attachment)
        try? modelContext.save()
    }

    // MARK: - Link save

    private func saveLink() {
        guard !linkURL.isEmpty else { resetLinkFields(); return }
        let title = linkTitle.isEmpty
            ? (URL(string: linkURL)?.host ?? linkURL)
            : linkTitle
        let attachment = FDTaskAttachment(type: .link, title: title, urlString: linkURL)
        attachment.task = task
        modelContext.insert(attachment)
        try? modelContext.save()
        resetLinkFields()
    }

    private func resetLinkFields() {
        linkURL = ""
        linkTitle = ""
    }

    // MARK: - Open / delete

    private func openAttachment(_ attachment: FDTaskAttachment) {
        guard let raw = attachment.urlString, let url = URL(string: raw) else { return }
        UIApplication.shared.open(url)
    }

    private func deleteAttachment(_ attachment: FDTaskAttachment) {
        if let raw = attachment.urlString,
           let url = URL(string: raw),
           url.isFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(attachment)
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func writeToAttachmentsDir(data: Data, filename: String) -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(filename)
        try? data.write(to: dest)
        return dest
    }

    private func makeThumbnail(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = CGSize(width: 76, height: 76)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.7) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .photo: return "photo"
        case .file:  return "doc"
        case .link:  return "link"
        }
    }
}
