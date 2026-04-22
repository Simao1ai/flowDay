// TaskAttachment.swift
// FlowDay

import Foundation
import UIKit

enum AttachmentType: String, Codable, CaseIterable {
    case photo
    case file
    case link
}

struct TaskAttachment: Codable, Identifiable {
    var id: UUID
    var filename: String
    var type: AttachmentType
    /// Filename relative to Documents/Attachments/ for photo and file types.
    var localPath: String
    /// JPEG-compressed ~100×100 thumbnail. nil for file/link types without previews.
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        filename: String,
        type: AttachmentType,
        localPath: String,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.filename = filename
        self.type = type
        self.localPath = localPath
        self.thumbnailData = thumbnailData
    }
}

// MARK: - File helpers

extension TaskAttachment {
    static var attachmentsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var fileURL: URL {
        TaskAttachment.attachmentsDirectory.appendingPathComponent(localPath)
    }

    func deleteFile() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var displayIcon: String {
        switch type {
        case .photo: return "photo.fill"
        case .file:  return "doc.fill"
        case .link:  return "link"
        }
    }
}
