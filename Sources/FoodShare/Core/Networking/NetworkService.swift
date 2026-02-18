
#if !SKIP
import Foundation

/// High-level network service for type-safe API requests
protocol NetworkService: Sendable {
    /// Execute a network request and decode the response
    func execute<Request: NetworkRequest>(_ request: Request) async throws -> Request.Response
}

/// Default implementation of NetworkService
actor NetworkServiceImpl: NetworkService {
    private let baseURL: URL
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        httpClient: HTTPClient = HTTPClientImpl(),
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.decoder = decoder
        self.encoder = encoder

        // Configure default decoder settings
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        // Configure default encoder settings
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func execute<Request: NetworkRequest>(_ request: Request) async throws -> Request.Response {
        let urlRequest = try buildURLRequest(from: request)
        let endpoint = request.path

        let (data, _) = try await httpClient.perform(urlRequest)

        guard !data.isEmpty else {
            throw NetworkError.noData(endpoint: endpoint)
        }

        do {
            return try decoder.decode(Request.Response.self, from: data)
        } catch {
            throw NetworkError.decodingError(error, endpoint: endpoint)
        }
    }

    // MARK: - Private

    private func buildURLRequest(from request: some NetworkRequest) throws -> URLRequest {
        let fullPath = baseURL.appendingPathComponent(request.path).absoluteString

        guard var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: false,
        ) else {
            throw NetworkError.invalidURL(fullPath)
        }

        // Add query items
        if let queryItems = request.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL(fullPath)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout

        // Add headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add body
        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}

#endif
