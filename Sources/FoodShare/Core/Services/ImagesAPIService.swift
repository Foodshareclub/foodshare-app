//
//  ImagesAPIService.swift
//  Foodshare
//

import Foundation

actor ImagesAPIService {
    nonisolated static let shared = ImagesAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func uploadImage(data: Data, filename: String) async throws -> ImageUploadResponse {
        try await client.post("api-v1-images/upload", body: ["data": data.base64EncodedString(), "filename": filename])
    }
    
    func optimizeImage(url: String, width: Int?, height: Int?) async throws -> ImageOptimizeResponse {
        var params: [String: String] = ["url": url]
        if let width = width { params["width"] = "\(width)" }
        if let height = height { params["height"] = "\(height)" }
        return try await client.get("api-v1-images/optimize", params: params)
    }
    
    func deleteImage(id: String) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-images", params: ["id": id])
    }
}

struct ImageUploadResponse: Codable {
    let url: String
    let id: String
}

struct ImageOptimizeResponse: Codable {
    let url: String
}
