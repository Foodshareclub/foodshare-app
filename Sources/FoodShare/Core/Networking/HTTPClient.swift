import Foundation

/// Low-level HTTP client for making network requests
protocol HTTPClient: Sendable {
    /// Perform a URL request
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default implementation using URLSession
actor HTTPClientImpl: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let endpoint = request.url?.path ?? "unknown"
        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)

            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                try validateHTTPResponse(httpResponse, endpoint: endpoint)
            }

            return (data, response)
        } catch let error as NetworkError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error, endpoint: endpoint, duration: Date().timeIntervalSince(startTime))
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Private

    private func validateHTTPResponse(_ response: HTTPURLResponse, endpoint: String) throws {
        switch response.statusCode {
        case 200 ... 299:
            return // Success
        case 401:
            throw NetworkError.unauthorized(endpoint: endpoint)
        case 403:
            throw NetworkError.forbidden(endpoint: endpoint)
        case 404:
            throw NetworkError.notFound(endpoint: endpoint)
        case 429:
            // Rate limited - check for Retry-After header
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) } ?? 60.0
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 400 ... 499:
            throw NetworkError.serverError(statusCode: response.statusCode, message: nil, endpoint: endpoint)
        case 500 ... 599:
            throw NetworkError.serverError(statusCode: response.statusCode, message: "Server error", endpoint: endpoint)
        default:
            throw NetworkError.serverError(statusCode: response.statusCode, message: nil, endpoint: endpoint)
        }
    }

    private func mapURLError(_ error: URLError, endpoint: String, duration: TimeInterval) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            .noInternetConnection
        case .timedOut:
            .timeout(endpoint: endpoint, duration: duration)
        default:
            .unknown(error)
        }
    }
}
