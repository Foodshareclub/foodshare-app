//
//  LegalDocumentService.swift
//  FoodShare
//
//  Service for fetching localized legal documents via ProfileAPIService
//

import Foundation
import OSLog

// MARK: - Legal Document Types

enum LegalDocumentType: String, Sendable {
    case terms
    case privacy
}

// MARK: - Legal Document Service

@MainActor
final class LegalDocumentService {
    static let shared = LegalDocumentService()

    private let api: ProfileAPIService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "LegalDocumentService")

    // Cache for legal documents
    private var cache: [String: (document: LegalDocument, fetchedAt: Date)] = [:]
    private let cacheMaxAge: TimeInterval = 3600 // 1 hour

    private init(api: ProfileAPIService = .shared) {
        self.api = api
    }

    /// Fetch a legal document by type and locale
    func fetchDocument(type: LegalDocumentType, locale: String) async throws -> LegalDocument {
        let cacheKey = "\(type.rawValue)_\(locale)"

        // Check cache first
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < cacheMaxAge {
            logger.debug("Legal document served from cache: \(cacheKey)")
            return cached.document
        }

        // Fetch from API
        logger.info("Fetching legal document: \(type.rawValue) for locale: \(locale)")

        let document = try await api.getLegalDocument(type: type.rawValue, locale: locale)

        // Cache the result
        cache[cacheKey] = (document: document, fetchedAt: Date())

        logger.info("Legal document fetched successfully: \(document.title)")
        return document
    }

    /// Fetch Terms of Service for current locale
    func fetchTermsOfService(locale: String) async throws -> LegalDocument {
        try await fetchDocument(type: .terms, locale: locale)
    }

    /// Fetch Privacy Policy for current locale
    func fetchPrivacyPolicy(locale: String) async throws -> LegalDocument {
        try await fetchDocument(type: .privacy, locale: locale)
    }

    /// Clear cached documents
    func clearCache() {
        cache.removeAll()
        logger.info("Legal document cache cleared")
    }
}

// MARK: - Error Types

enum LegalDocumentError: LocalizedError {
    case fetchFailed(String)
    case documentNotFound

    var errorDescription: String? {
        switch self {
        case let .fetchFailed(message):
            "Failed to fetch legal document: \(message)"
        case .documentNotFound:
            "Legal document not found"
        }
    }
}
