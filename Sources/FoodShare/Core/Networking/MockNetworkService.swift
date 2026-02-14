import Foundation

/// Mock network service for testing
actor MockNetworkService: NetworkService {
    var mockResponse: Any?
    var mockError: Error?
    var requestExecuted = false
    var lastRequest: Any?

    func execute<Request: NetworkRequest>(_ request: Request) async throws -> Request.Response {
        requestExecuted = true
        lastRequest = request

        if let error = mockError {
            throw error
        }

        guard let response = mockResponse as? Request.Response else {
            throw NetworkError.noData(endpoint: request.path)
        }

        return response
    }

    func reset() {
        mockResponse = nil
        mockError = nil
        requestExecuted = false
        lastRequest = nil
    }
}
