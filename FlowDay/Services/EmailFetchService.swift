// EmailFetchService.swift
// FlowDay — Fetch recent emails from connected accounts

import Foundation

// MARK: - Email Message

struct EmailMessage: Identifiable {
    let id: String
    let from: String
    let subject: String
    let snippet: String
    let date: Date
    let provider: EmailProvider
    let isRead: Bool
}

// MARK: - Email Fetch Service

final class EmailFetchService {

    private let accountService: EmailAccountService

    init(accountService: EmailAccountService) {
        self.accountService = accountService
    }

    // MARK: - Public API

    func fetchAllAccounts() async -> [EmailMessage] {
        var messages: [EmailMessage] = []

        await withTaskGroup(of: [EmailMessage].self) { group in
            for account in accountService.listConnections() {
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return await self.fetch(for: account.provider)
                }
            }
            for await batch in group {
                messages.append(contentsOf: batch)
            }
        }

        return messages.sorted { $0.date > $1.date }
    }

    func fetch(for provider: EmailProvider) async -> [EmailMessage] {
        switch provider {
        case .gmail:   return await fetchGmail()
        case .outlook: return await fetchOutlook()
        case .iCloud:  return await fetchICloud()
        }
    }

    // MARK: - Gmail

    private func fetchGmail() async -> [EmailMessage] {
        guard let token = accountService.accessToken(for: .gmail) else { return [] }

        // Step 1: List recent message IDs
        guard let listURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=20&q=newer_than:1d") else {
            return []
        }

        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (listData, listResponse) = try await URLSession.shared.data(for: listRequest)

            if let http = listResponse as? HTTPURLResponse, http.statusCode == 401 {
                guard await accountService.refreshGmailToken(),
                      let freshToken = accountService.accessToken(for: .gmail) else { return [] }
                return await fetchGmailWithToken(freshToken)
            }

            let listResult = try JSONDecoder().decode(GmailMessageListResponse.self, from: listData)
            guard let messageIds = listResult.messages?.map(\.id), !messageIds.isEmpty else { return [] }

            // Step 2: Fetch metadata for each message in parallel
            return await withTaskGroup(of: EmailMessage?.self) { group in
                for id in messageIds {
                    group.addTask {
                        await self.fetchGmailMessage(id: id, token: token)
                    }
                }
                var results: [EmailMessage] = []
                for await msg in group {
                    if let msg { results.append(msg) }
                }
                return results
            }

        } catch {
            return []
        }
    }

    private func fetchGmailWithToken(_ token: String) async -> [EmailMessage] {
        guard let listURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=20&q=newer_than:1d") else {
            return []
        }
        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (listData, _) = try await URLSession.shared.data(for: listRequest)
            let listResult = try JSONDecoder().decode(GmailMessageListResponse.self, from: listData)
            guard let messageIds = listResult.messages?.map(\.id), !messageIds.isEmpty else { return [] }
            return await withTaskGroup(of: EmailMessage?.self) { group in
                for id in messageIds {
                    group.addTask { await self.fetchGmailMessage(id: id, token: token) }
                }
                var results: [EmailMessage] = []
                for await msg in group {
                    if let msg { results.append(msg) }
                }
                return results
            }
        } catch {
            return []
        }
    }

    private func fetchGmailMessage(id: String, token: String) async -> EmailMessage? {
        let urlString = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let msg = try JSONDecoder().decode(GmailMessageDetail.self, from: data)

            let headers = msg.payload?.headers ?? []
            let from    = headers.first(where: { $0.name.lowercased() == "from"    })?.value ?? ""
            let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(no subject)"
            let dateStr = headers.first(where: { $0.name.lowercased() == "date"    })?.value ?? ""
            let date    = parseEmailDate(dateStr) ?? .now
            let isRead  = !(msg.labelIds?.contains("UNREAD") ?? false)

            return EmailMessage(
                id: msg.id,
                from: from,
                subject: subject,
                snippet: msg.snippet ?? "",
                date: date,
                provider: .gmail,
                isRead: isRead
            )
        } catch {
            return nil
        }
    }

    // MARK: - Outlook

    private func fetchOutlook() async -> [EmailMessage] {
        guard let token = accountService.accessToken(for: .outlook) else { return [] }
        return await fetchOutlookWithToken(token)
    }

    private func fetchOutlookWithToken(_ token: String) async -> [EmailMessage] {
        let urlString = "https://graph.microsoft.com/v1.0/me/messages?$top=20&$orderby=receivedDateTime%20desc&$select=id,from,subject,bodyPreview,receivedDateTime,isRead"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                guard await accountService.refreshOutlookToken(),
                      let freshToken = accountService.accessToken(for: .outlook) else { return [] }
                return await fetchOutlookWithToken(freshToken)
            }

            let result = try JSONDecoder().decode(OutlookMessageListResponse.self, from: data)

            return result.value?.compactMap { item -> EmailMessage? in
                guard let id      = item.id,
                      let subject = item.subject,
                      let dateStr = item.receivedDateTime,
                      let date    = ISO8601DateFormatter().date(from: dateStr) else { return nil }

                let from = item.from?.emailAddress?.address ?? item.from?.emailAddress?.name ?? ""

                return EmailMessage(
                    id: id,
                    from: from,
                    subject: subject,
                    snippet: item.bodyPreview ?? "",
                    date: date,
                    provider: .outlook,
                    isRead: item.isRead ?? true
                )
            } ?? []

        } catch {
            return []
        }
    }

    // MARK: - iCloud (IMAP stub — full IMAP implementation is Phase 2)

    private func fetchICloud() async -> [EmailMessage] {
        // IMAP from iOS requires a full IMAP client library.
        // Phase 1 stores credentials; Phase 2 will implement the IMAP fetch.
        return []
    }

    // MARK: - Helpers

    private func parseEmailDate(_ raw: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
                return f
            }(),
            {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "d MMM yyyy HH:mm:ss Z"
                return f
            }(),
        ]
        for formatter in formatters {
            if let date = formatter.date(from: raw) { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }
}

// MARK: - Gmail API Response Models

private struct GmailMessageListResponse: Codable {
    let messages: [GmailMessageRef]?
    let resultSizeEstimate: Int?
}

private struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

private struct GmailMessageDetail: Codable {
    let id: String
    let snippet: String?
    let labelIds: [String]?
    let payload: GmailPayload?
}

private struct GmailPayload: Codable {
    let headers: [GmailHeader]?
}

private struct GmailHeader: Codable {
    let name: String
    let value: String
}

// MARK: - Outlook Graph API Response Models

private struct OutlookMessageListResponse: Codable {
    let value: [OutlookMessage]?
}

private struct OutlookMessage: Codable {
    let id: String?
    let subject: String?
    let bodyPreview: String?
    let receivedDateTime: String?
    let isRead: Bool?
    let from: OutlookEmailWrapper?
}

private struct OutlookEmailWrapper: Codable {
    let emailAddress: OutlookEmailAddress?
}

private struct OutlookEmailAddress: Codable {
    let name: String?
    let address: String?
}
