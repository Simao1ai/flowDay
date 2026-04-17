// LLMService.swift
// FlowDay
//
// Dual-provider LLM service with automatic fallback.
// Supports OpenAI (GPT-4o), Anthropic (Claude Sonnet), and Google Gemini with seamless provider switching.
// API keys stored securely in Keychain (migrated from UserDefaults on first launch).

import Foundation
import Observation

// MARK: - LLM Types

struct LLMMessage {
    let role: MessageRole
    let content: String

    enum MessageRole: String {
        case system
        case user
        case assistant
    }
}

enum LLMError: Error, LocalizedError {
    case noAPIKey
    case bothProvidersFailed(primary: Error, fallback: Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No LLM API keys configured."
        case .bothProvidersFailed(let primary, let fallback):
            return "Both LLM providers failed. Primary: \(primary.localizedDescription). Fallback: \(fallback.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from LLM provider."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noAPIKey:
            return "Add your Google Gemini, OpenAI, or Anthropic API key in settings."
        case .bothProvidersFailed:
            return "Check your API keys and internet connection, then try again."
        case .invalidResponse:
            return "The LLM provider returned an unexpected format. Try again."
        }
    }
}

enum LLMProvider: Hashable {
    case openAI
    case anthropic
    case gemini
}

// MARK: - OpenAI Types

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int

    struct OpenAIMessage: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message

        struct Message: Decodable {
            let content: String
        }
    }
}

// MARK: - Anthropic Types

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]

    struct AnthropicMessage: Encodable {
        let role: String
        let content: String
    }
}

private struct AnthropicResponse: Decodable {
    let content: [Content]

    struct Content: Decodable {
        let text: String
    }
}

// MARK: - Gemini Types

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig

    struct GeminiContent: Encodable {
        let role: String?
        let parts: [GeminiPart]
    }

    struct GeminiPart: Encodable {
        let text: String
    }

    struct GeminiGenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content

        struct Content: Decodable {
            let parts: [Part]

            struct Part: Decodable {
                let text: String
            }
        }
    }
}

// MARK: - LLMService

@Observable
final class LLMService {
    static let shared = LLMService()

    // Configuration
    var primaryProvider: LLMProvider = .openAI

    // MARK: - API Keys (Keychain-backed, migrated from UserDefaults)

    var openAIKey: String {
        get {
            KeychainHelper.shared.readString(for: "llm_openai_key") ?? ""
        }
        set {
            KeychainHelper.shared.saveString(newValue, for: "llm_openai_key")
        }
    }

    var anthropicKey: String {
        get {
            KeychainHelper.shared.readString(for: "llm_anthropic_key") ?? ""
        }
        set {
            KeychainHelper.shared.saveString(newValue, for: "llm_anthropic_key")
        }
    }

    var geminiKey: String {
        get {
            KeychainHelper.shared.readString(for: "llm_gemini_key") ?? ""
        }
        set {
            KeychainHelper.shared.saveString(newValue, for: "llm_gemini_key")
        }
    }

    // Model identifiers
    private let openAIModel = "gpt-4o"
    private let anthropicModel = "claude-sonnet-4-20250514"
    private let anthropicVersion = "2023-06-01"
    private let geminiModel = "gemini-2.0-flash"

    // Computed properties
    var isConfigured: Bool {
        !openAIKey.isEmpty || !anthropicKey.isEmpty || !geminiKey.isEmpty
    }

    var secondaryProvider: LLMProvider {
        switch primaryProvider {
        case .gemini:
            return !openAIKey.isEmpty ? .openAI : .anthropic
        case .openAI:
            return !geminiKey.isEmpty ? .gemini : .anthropic
        case .anthropic:
            return !geminiKey.isEmpty ? .gemini : .openAI
        }
    }

    private init() {
        migrateKeysFromUserDefaults()
    }

    // MARK: - Migration (UserDefaults → Keychain, one-time)

    func migrateKeysFromUserDefaults() {
        let defaults = UserDefaults.standard

        if let key = defaults.string(forKey: "llm_openai_key"), !key.isEmpty {
            KeychainHelper.shared.saveString(key, for: "llm_openai_key")
            defaults.removeObject(forKey: "llm_openai_key")
        }

        if let key = defaults.string(forKey: "llm_anthropic_key"), !key.isEmpty {
            KeychainHelper.shared.saveString(key, for: "llm_anthropic_key")
            defaults.removeObject(forKey: "llm_anthropic_key")
        }

        if let key = defaults.string(forKey: "llm_gemini_key"), !key.isEmpty {
            KeychainHelper.shared.saveString(key, for: "llm_gemini_key")
            defaults.removeObject(forKey: "llm_gemini_key")
        }

        defaults.synchronize()
    }

    // MARK: - Public Methods

    /// Send a chat message and get a response with automatic fallback
    func chat(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard isConfigured else {
            throw LLMError.noAPIKey
        }

        var primaryError: Error?
        var fallbackError: Error?

        // Try primary provider
        do {
            return try await callProvider(
                primaryProvider,
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch {
            primaryError = error
            #if DEBUG
            print("[LLMService] Primary provider (\(primaryProvider)) failed: \(error.localizedDescription)")
            #endif
        }

        // Try fallback provider
        do {
            return try await callProvider(
                secondaryProvider,
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch {
            fallbackError = error
            #if DEBUG
            print("[LLMService] Fallback provider (\(secondaryProvider)) also failed: \(error.localizedDescription)")
            #endif
        }

        throw LLMError.bothProvidersFailed(
            primary: primaryError ?? LLMError.invalidResponse,
            fallback: fallbackError ?? LLMError.invalidResponse
        )
    }

    /// Test connectivity to all providers
    func testConnection() async -> (openAI: Bool, anthropic: Bool, gemini: Bool) {
        async let openAIResult = testOpenAI()
        async let anthropicResult = testAnthropic()
        async let geminiResult = testGemini()

        let results = await (openAIResult, anthropicResult, geminiResult)
        return (openAI: results.0, anthropic: results.1, gemini: results.2)
    }

    // MARK: - Private Provider Methods

    private func callProvider(
        _ provider: LLMProvider,
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        switch provider {
        case .openAI:
            return try await callOpenAI(
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        case .anthropic:
            return try await callAnthropic(
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        case .gemini:
            return try await callGemini(
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        }
    }

    // MARK: - OpenAI Implementation

    private func callOpenAI(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard !openAIKey.isEmpty else {
            throw APIError.invalidAPIKey
        }

        let request = try buildOpenAIRequest(
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response: OpenAIResponse = try await APIClient.shared.request(OpenAIEndpoint(request: request, apiKey: openAIKey))

        guard let firstChoice = response.choices.first else {
            throw LLMError.invalidResponse
        }

        return firstChoice.message.content
    }

    private func buildOpenAIRequest(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw APIError.invalidURL
        }

        var allMessages: [OpenAIRequest.OpenAIMessage] = [
            OpenAIRequest.OpenAIMessage(role: "system", content: systemPrompt)
        ]

        for message in messages {
            allMessages.append(OpenAIRequest.OpenAIMessage(
                role: message.role.rawValue,
                content: message.content
            ))
        }

        let requestBody = OpenAIRequest(
            model: openAIModel,
            messages: allMessages,
            temperature: temperature,
            max_tokens: maxTokens
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        return request
    }

    private func testOpenAI() async -> Bool {
        guard !openAIKey.isEmpty else { return false }

        do {
            let testMessage = [LLMMessage(role: .user, content: "Say 'OK'")]
            _ = try await callOpenAI(
                messages: testMessage,
                systemPrompt: "You are a helpful assistant.",
                temperature: 0.7,
                maxTokens: 10
            )
            return true
        } catch {
            #if DEBUG
            print("[LLMService] OpenAI test failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Anthropic Implementation

    private func callAnthropic(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard !anthropicKey.isEmpty else {
            throw APIError.invalidAPIKey
        }

        let request = try buildAnthropicRequest(
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )

        let response: AnthropicResponse = try await APIClient.shared.request(AnthropicEndpoint(request: request, apiKey: anthropicKey))

        guard let firstContent = response.content.first else {
            throw LLMError.invalidResponse
        }

        return firstContent.text
    }

    private func buildAnthropicRequest(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw APIError.invalidURL
        }

        var anthropicMessages: [AnthropicRequest.AnthropicMessage] = []

        for message in messages {
            // Skip system messages; we'll use the system parameter instead
            if message.role != .system {
                anthropicMessages.append(AnthropicRequest.AnthropicMessage(
                    role: message.role.rawValue,
                    content: message.content
                ))
            }
        }

        let requestBody = AnthropicRequest(
            model: anthropicModel,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: anthropicMessages
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        return request
    }

    private func testAnthropic() async -> Bool {
        guard !anthropicKey.isEmpty else { return false }

        do {
            let testMessage = [LLMMessage(role: .user, content: "Say 'OK'")]
            _ = try await callAnthropic(
                messages: testMessage,
                systemPrompt: "You are a helpful assistant.",
                temperature: 0.7,
                maxTokens: 10
            )
            return true
        } catch {
            #if DEBUG
            print("[LLMService] Anthropic test failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }
    // MARK: - Gemini Implementation

    private func callGemini(
        messages: [LLMMessage],
        systemPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard !geminiKey.isEmpty else {
            throw APIError.invalidAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(geminiKey)") else {
            throw APIError.invalidURL
        }

        var geminiContents: [GeminiRequest.GeminiContent] = []

        for message in messages {
            if message.role != .system {
                let role = message.role == .assistant ? "model" : "user"
                geminiContents.append(GeminiRequest.GeminiContent(
                    role: role,
                    parts: [GeminiRequest.GeminiPart(text: message.content)]
                ))
            }
        }

        let requestBody = GeminiRequest(
            contents: geminiContents,
            systemInstruction: GeminiRequest.GeminiContent(
                role: nil,
                parts: [GeminiRequest.GeminiPart(text: systemPrompt)]
            ),
            generationConfig: GeminiRequest.GeminiGenerationConfig(
                temperature: temperature,
                maxOutputTokens: maxTokens
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw LLMError.invalidResponse
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let firstCandidate = geminiResponse.candidates?.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw LLMError.invalidResponse
        }

        return firstPart.text
    }

    private func testGemini() async -> Bool {
        guard !geminiKey.isEmpty else { return false }

        do {
            let testMessage = [LLMMessage(role: .user, content: "Say 'OK'")]
            _ = try await callGemini(
                messages: testMessage,
                systemPrompt: "You are a helpful assistant.",
                temperature: 0.7,
                maxTokens: 10
            )
            return true
        } catch {
            #if DEBUG
            print("[LLMService] Gemini test failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }
}

// MARK: - APIEndpoint Implementations

private struct OpenAIEndpoint: APIEndpoint {
    typealias ResponseType = OpenAIResponse

    let request: URLRequest
    let apiKey: String

    var url: URL {
        request.url ?? URL(string: "https://api.openai.com/v1/chat/completions")! // Safe: hardcoded valid URL
    }

    var method: HTTPMethod { .post }

    var headers: [String: String] {
        var headers = [String: String]()
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            headers["Authorization"] = authHeader
        }
        headers["Content-Type"] = "application/json"
        return headers
    }

    var body: Data? {
        request.httpBody
    }
}

private struct AnthropicEndpoint: APIEndpoint {
    typealias ResponseType = AnthropicResponse

    let request: URLRequest
    let apiKey: String

    var url: URL {
        request.url ?? URL(string: "https://api.anthropic.com/v1/messages")! // Safe: hardcoded valid URL
    }

    var method: HTTPMethod { .post }

    var headers: [String: String] {
        var headers = [String: String]()
        headers["x-api-key"] = apiKey
        if let version = request.value(forHTTPHeaderField: "anthropic-version") {
            headers["anthropic-version"] = version
        } else {
            headers["anthropic-version"] = "2023-06-01"
        }
        headers["Content-Type"] = "application/json"
        return headers
    }

    var body: Data? {
        request.httpBody
    }
}
