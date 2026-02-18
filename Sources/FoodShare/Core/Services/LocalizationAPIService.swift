//
//  LocalizationAPIService.swift
//  Foodshare
//
//  Centralized API service for localization/translation
//


#if !SKIP
import Foundation

// MARK: - Request Bodies

private struct TranslateBody: Encodable {
    let text: String
    let targetLanguage: String
}

private struct ContentTranslationsBody: Encodable {
    let contentType: String
    let contentIds: [String]
    let locale: String
    let fields: [String]
}

// MARK: - Service

actor LocalizationAPIService {
    nonisolated static let shared = LocalizationAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func translate(text: String, targetLanguage: String) async throws -> TranslationResponse {
        let payload = TranslateBody(text: text, targetLanguage: targetLanguage)
        return try await client.post("api-v1-localization/translate", body: payload)
    }

    func getTranslations(language: String) async throws -> [String: String] {
        try await client.get("api-v1-localization/strings", params: ["language": language])
    }

    func getContentTranslations(contentType: String, contentIds: [String], locale: String, fields: [String]) async throws -> LocalizationContentResponse {
        let payload = ContentTranslationsBody(contentType: contentType, contentIds: contentIds, locale: locale, fields: fields)
        return try await client.post("api-v1-localization/get-translations", body: payload)
    }
}

struct LocalizationContentResponse: Codable {
    let success: Bool
    let translations: [String: [String: String]]
}

struct TranslationResponse: Codable {
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}

#endif
