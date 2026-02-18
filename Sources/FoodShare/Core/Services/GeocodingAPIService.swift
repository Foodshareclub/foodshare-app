//
//  GeocodingAPIService.swift
//  Foodshare
//


#if !SKIP
import Foundation

actor GeocodingAPIService {
    nonisolated static let shared = GeocodingAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func geocode(address: String) async throws -> GeocodingResponse {
        try await client.get("api-v1-geocoding", params: ["address": address])
    }
    
    func reverseGeocode(lat: Double, lng: Double) async throws -> ReverseGeocodingResponse {
        try await client.get("api-v1-geocoding/reverse", params: ["lat": "\(lat)", "lng": "\(lng)"])
    }
}

struct GeocodingResponse: Codable {
    let lat: Double
    let lng: Double
    let formattedAddress: String
}

struct ReverseGeocodingResponse: Codable {
    let address: String
    let city: String?
    let country: String?
}

#endif
