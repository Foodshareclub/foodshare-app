//
//  EdgeFunctionResponse.swift
//  Foodshare
//
//  Standard response envelope matching Edge Function API responses.
//  All edge functions return { success, data, meta, pagination?, error? }
//

import Foundation

/// Standard envelope for all Edge Function responses
struct EdgeResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let meta: EdgeResponseMeta?
    let pagination: EdgePagination?
    let error: EdgeErrorDetail?
}

/// Metadata included in every Edge Function response
struct EdgeResponseMeta: Decodable {
    let requestId: String?
    let timestamp: String?
    let responseTime: Int?
    let cacheTTL: Int?
    let version: String?
}

/// Error detail returned when `success == false`
struct EdgeErrorDetail: Decodable, Sendable {
    let code: String
    let message: String
    let details: [String: AnyCodable]?
}

/// Pagination info for paginated Edge Function responses
struct EdgePagination: Decodable, Sendable {
    let offset: Int?
    let limit: Int?
    let total: Int?
    let hasMore: Bool?
    let nextOffset: Int?
    let nextCursor: String?
}
