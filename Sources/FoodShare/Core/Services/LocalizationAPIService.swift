//
//  LocalizationAPIService.swift
//  Foodshare
//
//  Centralized API service for localization/translation
//

import Foundation

actor LocalizationAPIService {
    nonisolated static let shared = LocalizationAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func translate(text: String, targetLanguage: String) async throws -> TranslationResponse {
        try await client.post("api-v1-localization/translate", body: [
            "text": text,
            "targetLanguage": targetLanguage
        ])
    }
    
    func getTranslations(language: String) async throws -> [String: String] {
        try await client.get("api-v1-localization/strings", params: ["language": language])
    }
    
    func getContentTranslations(contentType: String, contentIds: [String], locale: String, fields: [String]) async throws -> ContentTranslationsResponse {
        try await client.post("api-v1-localization/get-translations", body: [
            "contentType": contentType,
            "contentIds": contentIds,
            "locale": locale,
            "fields": fields
        ])
    }
}

struct ContentTranslationsResponse: Codable {
    let success: Bool
    let translations: [String: [String: String]]
}

struct TranslationResponse: Codable {
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}
