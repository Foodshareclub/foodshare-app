
#if !SKIP
import Foundation

/// Protocol defining network request parameters
protocol NetworkRequest: Sendable {
    associatedtype Response: Decodable & Sendable

    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var timeout: TimeInterval { get }
}

extension NetworkRequest {
    /// Default headers
    var headers: [String: String]? { nil }

    /// Default query items
    var queryItems: [URLQueryItem]? { nil }

    /// Default body
    var body: Data? { nil }

    /// Default timeout
    var timeout: TimeInterval { 30.0 }
}

#endif
