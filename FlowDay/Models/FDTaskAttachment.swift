// FDTaskAttachment.swift
// FlowDay — Wave 4b

import Foundation
import SwiftData

enum AttachmentType: String, Codable {
    case photo
    case file
    case link
}

@Model
final class FDTaskAttachment {
    var id: UUID
    var type: AttachmentType
    var title: String
    var urlString: String?
    var thumbnailData: Data?
    var createdAt: Date

    @Relationship(inverse: \FDTask.attachments)
    var task: FDTask?

    init(
        type: AttachmentType,
        title: String,
        urlString: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.urlString = urlString
        self.thumbnailData = thumbnailData
        self.createdAt = .now
    }
}
