// TaskAttachment.swift
// FlowDay

import Foundation
import SwiftData

@Model
final class TaskAttachment {
    var id: UUID
    var filename: String
    // "photo" | "pdf" | "file" | "link"
    var attachmentType: String
    // Path relative to app's Documents directory (nil for link type)
    var localPath: String?
    // Used only when attachmentType == "link"
    var urlString: String?
    // Compressed JPEG thumbnail (photos only)
    var thumbnailData: Data?
    var fileSize: Int64
    var createdAt: Date

    @Relationship(inverse: \FDTask.attachments)
    var task: FDTask?

    init(
        filename: String,
        attachmentType: String,
        localPath: String? = nil,
        urlString: String? = nil,
        thumbnailData: Data? = nil,
        fileSize: Int64 = 0
    ) {
        self.id = UUID()
        self.filename = filename
        self.attachmentType = attachmentType
        self.localPath = localPath
        self.urlString = urlString
        self.thumbnailData = thumbnailData
        self.fileSize = fileSize
        self.createdAt = .now
    }
}

// MARK: - Convenience

extension TaskAttachment {

    enum Kind: String {
        case photo = "photo"
        case pdf   = "pdf"
        case file  = "file"
        case link  = "link"
    }

    var kind: Kind { Kind(rawValue: attachmentType) ?? .file }

    var systemIcon: String {
        switch kind {
        case .photo: "photo"
        case .pdf:   "doc.richtext"
        case .file:  "doc"
        case .link:  "link"
        }
    }

    var resolvedLocalURL: URL? {
        guard let path = localPath else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(path)
    }

    var formattedSize: String {
        guard fileSize > 0 else { return "" }
        if fileSize < 1024 { return "\(fileSize) B" }
        if fileSize < 1_048_576 { return "\(fileSize / 1024) KB" }
        return String(format: "%.1f MB", Double(fileSize) / 1_048_576)
    }
}
