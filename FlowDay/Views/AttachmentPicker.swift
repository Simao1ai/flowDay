// AttachmentPicker.swift
// FlowDay

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Photo Picker (PHPickerViewController — no NSPhotoLibraryUsageDescription required)

struct PhotoAttachmentPicker: UIViewControllerRepresentable {
    let onPicked: (TaskAttachment) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (TaskAttachment) -> Void
        init(onPicked: @escaping (TaskAttachment) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                guard let data, let self else { return }
                let baseName = result.itemProvider.suggestedName ?? "photo_\(UUID().uuidString)"
                let filename = "\(baseName).jpg"
                let attachment = self.save(data: data, filename: filename)
                DispatchQueue.main.async { self.onPicked(attachment) }
            }
        }

        private func save(data: Data, filename: String) -> TaskAttachment {
            let subdir = attachmentsDir()
            let dest = subdir.appendingPathComponent(filename)
            try? data.write(to: dest)

            var thumbnail: Data?
            if let img = UIImage(data: data) {
                let size = CGSize(width: 120, height: 120)
                thumbnail = UIGraphicsImageRenderer(size: size).image { _ in
                    img.draw(in: CGRect(origin: .zero, size: size))
                }.jpegData(compressionQuality: 0.6)
            }

            return TaskAttachment(
                filename: filename,
                attachmentType: "photo",
                localPath: "attachments/\(filename)",
                thumbnailData: thumbnail,
                fileSize: Int64(data.count)
            )
        }
    }
}

// MARK: - File Picker (UIDocumentPickerViewController)

struct FileAttachmentPicker: UIViewControllerRepresentable {
    let onPicked: (TaskAttachment) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .text, .spreadsheet, .presentation, .data, .archive]
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (TaskAttachment) -> Void
        init(onPicked: @escaping (TaskAttachment) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
            let filename = url.lastPathComponent
            let subdir = attachmentsDir()
            let dest = subdir.appendingPathComponent(filename)
            try? data.write(to: dest)
            let kind = filename.lowercased().hasSuffix(".pdf") ? "pdf" : "file"
            let attachment = TaskAttachment(
                filename: filename,
                attachmentType: kind,
                localPath: "attachments/\(filename)",
                fileSize: Int64(data.count)
            )
            DispatchQueue.main.async { self.onPicked(attachment) }
        }
    }
}

// MARK: - Shared helpers

private func attachmentsDir() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("attachments", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
