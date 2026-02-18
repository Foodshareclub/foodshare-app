//
//  APIClient.swift
//  Foodshare
//
//  Centralized API client for all Edge Function calls.
//  Handles authentication, request/response encoding, error parsing,
//  and the standard Edge Function response envelope.
//


#if !SKIP
import Foundation
import Supabase

actor APIClient {
    nonisolated static let shared = APIClient(supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase })

    private let supabase: SupabaseClient
    private let baseURL: String
    private let session: URLSession

    /// Shared decoder configured for Edge Function responses
    nonisolated static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }

            // Fallback to ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return decoder
    }()

    /// Shared encoder for request bodies
    nonisolated static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        self.baseURL = "\(AppEnvironment.supabaseURL ?? "https://api.foodshare.club")/functions/v1"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        try await request(endpoint: endpoint, method: .get, params: params)
    }

    func post<T: Decodable, B: Encodable>(_ endpoint: String, body: B, params: [String: String] = [:]) async throws -> T {
        try await request(endpoint: endpoint, method: .post, body: body, params: params)
    }

    func post<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        try await request(endpoint: endpoint, method: .post, params: params)
    }

    func put<T: Decodable, B: Encodable>(_ endpoint: String, body: B, params: [String: String] = [:]) async throws -> T {
        try await request(endpoint: endpoint, method: .put, body: body, params: params)
    }

    func delete<T: Decodable>(_ endpoint: String, params: [String: String] = [:]) async throws -> T {
        try await request(endpoint: endpoint, method: .delete, params: params)
    }

    // MARK: - Void Methods (fire-and-forget operations)

    func postVoid<B: Encodable>(_ endpoint: String, body: B, params: [String: String] = [:]) async throws {
        try await requestVoid(endpoint: endpoint, method: .post, body: body, params: params)
    }

    func postVoid(_ endpoint: String, params: [String: String] = [:]) async throws {
        try await requestVoid(endpoint: endpoint, method: .post, params: params)
    }

    func putVoid<B: Encodable>(_ endpoint: String, body: B, params: [String: String] = [:]) async throws {
        try await requestVoid(endpoint: endpoint, method: .put, body: body, params: params)
    }

    func deleteVoid(_ endpoint: String, params: [String: String] = [:]) async throws {
        try await requestVoid(endpoint: endpoint, method: .delete, params: params)
    }

    // MARK: - Private Implementation

    private func request<T: Decodable, B: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: B? = nil as EmptyBody?,
        params: [String: String] = [:]
    ) async throws -> T {
        let (data, _) = try await executeRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            params: params
        )

        // Decode the Edge Function envelope
        do {
            let envelope = try Self.decoder.decode(EdgeResponse<T>.self, from: data)

            guard envelope.success else {
                if let error = envelope.error {
                    throw EdgeFunctionError.from(code: error.code, message: error.message)
                }
                throw EdgeFunctionError.serverError("Request failed with no error details")
            }

            guard let responseData = envelope.data else {
                throw EdgeFunctionError.decodingError("Response succeeded but contained no data")
            }

            return responseData
        } catch let error as EdgeFunctionError {
            throw error
        } catch {
            // If envelope decoding fails, try decoding T directly (some endpoints may not use envelope)
            do {
                return try Self.decoder.decode(T.self, from: data)
            } catch {
                throw EdgeFunctionError.decodingError(error.localizedDescription)
            }
        }
    }

    /// Extracts both data and pagination from the response envelope
    func getWithPagination<T: Decodable>(
        _ endpoint: String,
        params: [String: String] = [:]
    ) async throws -> (data: T, pagination: EdgePagination?) {
        let (data, _) = try await executeRequest(
            endpoint: endpoint,
            method: .get,
            body: nil as EmptyBody?,
            params: params
        )

        let envelope = try Self.decoder.decode(EdgeResponse<T>.self, from: data)

        guard envelope.success else {
            if let error = envelope.error {
                throw EdgeFunctionError.from(code: error.code, message: error.message)
            }
            throw EdgeFunctionError.serverError("Request failed with no error details")
        }

        guard let responseData = envelope.data else {
            throw EdgeFunctionError.decodingError("Response succeeded but contained no data")
        }

        return (responseData, envelope.pagination)
    }

    private func requestVoid<B: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: B? = nil as EmptyBody?,
        params: [String: String] = [:]
    ) async throws {
        let (data, httpResponse) = try await executeRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            params: params
        )

        // 204 No Content — nothing to parse
        if httpResponse.statusCode == 204 { return }

        // Check for error envelope on non-204 responses
        if let envelope = try? Self.decoder.decode(EdgeResponse<EmptyResponse>.self, from: data),
           !envelope.success,
           let error = envelope.error
        {
            throw EdgeFunctionError.from(code: error.code, message: error.message)
        }
    }

    private func executeRequest<B: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: B?,
        params: [String: String]
    ) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("ios", forHTTPHeaderField: "X-Client-Platform")

        // Add idempotency key for mutating requests
        if method == .post || method == .put {
            urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Idempotency-Key")
        }

        // Add auth token
        if let token = try? await supabase.auth.session.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        if let body {
            urlRequest.httpBody = try Self.encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw EdgeFunctionError.timeout("Request timed out")
            case .notConnectedToInternet, .networkConnectionLost:
                throw EdgeFunctionError.networkError("No internet connection")
            default:
                throw EdgeFunctionError.networkError(urlError.localizedDescription)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EdgeFunctionError.networkError("Invalid response type")
        }

        // For non-success status codes without parseable envelope, throw HTTP error
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error envelope first
            if let envelope = try? Self.decoder.decode(EdgeResponse<EmptyResponse>.self, from: data),
               let error = envelope.error
            {
                throw EdgeFunctionError.from(code: error.code, message: error.message)
            }
            // Fall back to status code mapping
            let bodyString = String(data: data, encoding: .utf8)
            throw EdgeFunctionError.fromHTTPStatus(httpResponse.statusCode, body: bodyString)
        }

        return (data, httpResponse)
    }
}

// MARK: - Supporting Types

struct EmptyBody: Encodable {}

// MARK: - Legacy APIError (kept for backward compatibility during migration)

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .httpError(let code): "HTTP error: \(code)"
        }
    }
}

#endif
