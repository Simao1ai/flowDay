// APIClient.swift
// FlowDay
//
// Generic async/await networking client with retry logic and error handling.
// Handles HTTP requests, response decoding, and provides a foundation for all API integrations.

import Foundation

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case networkError(URLError)
    case decodingError(DecodingError)
    case serverError(Int, String)
    case rateLimited
    case unauthorized
    case invalidAPIKey
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .unauthorized:
            return "Unauthorized. Check your credentials."
        case .invalidAPIKey:
            return "Invalid API key."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .decodingError:
            return "The response format was unexpected. Try again."
        case .serverError:
            return "The server returned an error. Try again later."
        case .rateLimited:
            return "Wait a moment before making another request."
        case .unauthorized:
            return "Check your authentication credentials."
        case .invalidAPIKey:
            return "Verify your API key is correct and active."
        case .unknown:
            return "Try again or contact support."
        }
    }
}

// MARK: - APIEndpoint Protocol

protocol APIEndpoint {
    associatedtype ResponseType: Decodable

    var url: URL { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: Data? { get }
}

// Default implementations
extension APIEndpoint {
    var method: HTTPMethod { .get }
    var headers: [String: String] { [:] }
    var body: Data? { nil }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let timeout: TimeInterval = 30
    private let maxRetries = 1

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Request Method

    /// Make an async request to an API endpoint with automatic retry and error handling
    func request<E: APIEndpoint>(_ endpoint: E) async throws -> E.ResponseType {
        var lastError: APIError?

        for attempt in 0...maxRetries {
            do {
                return try await performRequest(endpoint)
            } catch let error as APIError {
                lastError = error

                // Determine if we should retry
                switch error {
                case .networkError:
                    if attempt < maxRetries {
                        #if DEBUG
                        print("[APIClient] Network error on attempt \(attempt + 1), retrying...")
                        #endif
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                        continue
                    }
                case .rateLimited:
                    // Exponential backoff for rate limiting
                    if attempt < maxRetries {
                        let backoffSeconds = pow(2.0, Double(attempt + 1))
                        #if DEBUG
                        print("[APIClient] Rate limited, backing off \(backoffSeconds)s...")
                        #endif
                        try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                        continue
                    }
                default:
                    throw error
                }
            } catch {
                lastError = .unknown(error)
                throw lastError ?? .unknown(error)
            }
        }

        throw lastError ?? .unknown(NSError(domain: "APIClient", code: -1))
    }

    // MARK: - Private Methods

    private func performRequest<E: APIEndpoint>(_ endpoint: E) async throws -> E.ResponseType {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = timeout

        // Set headers
        var headers = endpoint.headers
        if request.value(forHTTPHeaderField: "Content-Type") == nil && endpoint.body != nil {
            headers["Content-Type"] = "application/json"
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = endpoint.body

        #if DEBUG
        print("[APIClient] \(endpoint.method.rawValue) \(endpoint.url.absoluteString)")
        #endif

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }

        try validateStatusCode(httpResponse)

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(E.ResponseType.self, from: data)
            #if DEBUG
            print("[APIClient] Response decoded successfully")
            #endif
            return decoded
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[APIClient] Decoding error: \(decodingError)")
            #endif
            throw APIError.decodingError(decodingError)
        }
    }

    private func validateStatusCode(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 400:
            throw APIError.invalidAPIKey
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        case 500...599:
            let message = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw APIError.serverError(response.statusCode, message)
        default:
            let message = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw APIError.serverError(response.statusCode, message)
        }
    }
}
