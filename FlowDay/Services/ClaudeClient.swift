// ClaudeClient.swift
// FlowDay
//
// Calls the Supabase Edge Function at /functions/v1/claude.
// The Anthropic API key lives server-side as a Supabase secret — it is never
// present in the iOS binary. Auth is handled by the caller's Supabase session JWT.
//
// Usage:
//   let reply = try await ClaudeClient.shared.chat(
//     feature: .flowAI,
//     systemPrompt: nil,   // server provides the stable system prompt
//     messages: [.init(role: .user, content: "Plan my day")],
//     temperature: 0.7
//   )

import Foundation

// MARK: - Claude Feature

/// Identifies which server-side system prompt to use.
enum ClaudeFeature: String, Codable {
    case flowAI           = "flowAI"
    case templateGenerator = "templateGenerator"
}

// MARK: - Errors

enum ClaudeClientError: Error, LocalizedError {
    case notAuthenticated
    case serverError(Int, String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to use AI features."
        case .serverError(let code, let msg):
            return "AI service error (\(code)): \(msg)"
        case .invalidResponse:
            return "Unexpected response from AI service."
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Go to Settings and sign in to your FlowDay account."
        case .serverError:
            return "Try again in a moment."
        case .invalidResponse:
            return "Try again. If the issue persists, contact support."
        case .networkError:
            return "Check your internet connection and try again."
        }
    }
}

// MARK: - Request / Response Models

private struct ClaudeRequest: Encodable {
    let feature: ClaudeFeature
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case feature, messages, temperature
        case maxTokens = "maxTokens"
    }

    struct Message: Encodable {
        let role: String   // "user" | "assistant"
        let content: String
    }
}

private struct ClaudeResponse: Decodable {
    let content: String
    // error is present only when the edge function returns a non-2xx body
    let error: String?
}

// MARK: - ClaudeClient

final class ClaudeClient {
    static let shared = ClaudeClient()

    private init() {}

    // MARK: - Public API

    /// Send a message to the Edge Function and return the AI's text response.
    ///
    /// - Parameters:
    ///   - feature: Which server-side feature/system-prompt to invoke.
    ///   - messages: Conversation history. The last element should be the user's turn.
    ///   - temperature: Sampling temperature (0–1). Lower = more deterministic.
    ///   - maxTokens: Maximum tokens the model may generate in its response.
    func chat(
        feature: ClaudeFeature,
        messages: [LLMMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 2048
    ) async throws -> String {

        // Build the edge function URL
        let baseURL = FlowDayConfig.supabaseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/functions/v1/claude") else {
            throw ClaudeClientError.invalidResponse
        }

        // Retrieve the active session JWT from Supabase
        let jwt = try await SupabaseService.shared.currentAccessToken()

        // Map LLMMessage to the edge-function wire format (skip system messages —
        // the server always injects the correct system prompt for the feature)
        let edgeMessages = messages
            .filter { $0.role != .system }
            .map { ClaudeRequest.Message(role: $0.role.rawValue, content: $0.content) }

        let payload = ClaudeRequest(
            feature: feature,
            messages: edgeMessages,
            temperature: temperature,
            maxTokens: maxTokens
        )

        // Build the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60  // AI calls can take ~10–20 s; be generous
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        // Supabase Edge Functions also require the anon key as apikey header
        request.setValue(FlowDayConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw ClaudeClientError.networkError(error)
        }

        // Execute the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeClientError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeClientError.invalidResponse
        }

        // Log cache headers in DEBUG builds so we can verify caching is working
        #if DEBUG
        let cacheStatus = http.value(forHTTPHeaderField: "X-Cache-Status") ?? "unknown"
        let cacheReadTokens = http.value(forHTTPHeaderField: "X-Cache-Read-Tokens") ?? "0"
        let cacheCreationTokens = http.value(forHTTPHeaderField: "X-Cache-Creation-Tokens") ?? "0"
        print("[ClaudeClient] feature=\(feature.rawValue) cache=\(cacheStatus) " +
              "readTokens=\(cacheReadTokens) creationTokens=\(cacheCreationTokens) " +
              "status=\(http.statusCode)")
        #endif

        // Decode the response body (success or structured error)
        let decoded: ClaudeResponse
        do {
            decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            throw ClaudeClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ClaudeClientError.serverError(
                http.statusCode,
                decoded.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }

        return decoded.content
    }
}
