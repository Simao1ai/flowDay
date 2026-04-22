// AttachmentRow.swift
// FlowDay

import SwiftUI
import UIKit

struct AttachmentRow: View {
    let attachment: TaskAttachment
    let onDelete: () -> Void

    @State private var showPreview = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.kind == .link ? (attachment.urlString ?? attachment.filename) : attachment.filename)
                    .font(.fdCaption)
                    .foregroundStyle(Color.fdText)
                    .lineLimit(1)
                if !attachment.formattedSize.isEmpty {
                    Text(attachment.formattedSize)
                        .font(.fdMicro)
                        .foregroundStyle(Color.fdTextMuted)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fdTextMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if attachment.kind == .link, let str = attachment.urlString, let url = URL(string: str) {
                UIApplication.shared.open(url)
            } else {
                showPreview = true
            }
        }
        .sheet(isPresented: $showPreview) {
            AttachmentPreviewSheet(attachment: attachment)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = attachment.thumbnailData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: attachment.systemIcon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var iconColor: Color {
        switch attachment.kind {
        case .photo: .fdAccent
        case .pdf:   .fdRed
        case .file:  .fdBlue
        case .link:  .fdPurple
        }
    }
}

// MARK: - Preview Sheet

struct AttachmentPreviewSheet: View {
    let attachment: TaskAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = attachment.resolvedLocalURL, attachment.kind == .photo,
                   let img = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                } else if let url = attachment.resolvedLocalURL {
                    VStack(spacing: 20) {
                        Image(systemName: attachment.systemIcon)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.fdAccent)
                        Text(attachment.filename)
                            .font(.fdTitle3)
                            .foregroundStyle(Color.fdText)
                            .multilineTextAlignment(.center)
                        if !attachment.formattedSize.isEmpty {
                            Text(attachment.formattedSize)
                                .font(.fdCaption)
                                .foregroundStyle(Color.fdTextMuted)
                        }
                        Button("Open in Files") {
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.fdAccent)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fdBackground)
                } else if let urlStr = attachment.urlString, let url = URL(string: urlStr) {
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.fdPurple)
                        Text(urlStr)
                            .font(.fdBody)
                            .foregroundStyle(Color.fdText)
                            .multilineTextAlignment(.center)
                        Button("Open Link") {
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.fdPurple)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fdBackground)
                } else {
                    Text("Cannot preview this attachment.")
                        .foregroundStyle(Color.fdTextMuted)
                }
            }
            .navigationTitle(attachment.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
