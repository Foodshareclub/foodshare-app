//
//  EnhancedTranslationService.swift
//  Foodshare
//
//  Enterprise-grade translation service with Swift 6.2 best practices.
//  Features: Delta sync, background refresh, offline support, typed keys, RTL, pluralization.
//



#if !SKIP
import Foundation
import Observation
import OSLog
import Supabase
import SwiftUI
#if !SKIP
import UIKit
#endif

// MARK: - Translation Configuration

/// Centralized configuration for translation service.
public enum TranslationConfig: Sendable {
    public static let baseURL: URL = {
        guard let supabaseURL = AppEnvironment.supabaseURL,
              let url = URL(string: "\(supabaseURL)/functions/v1/api-v1-localization") else {
            assertionFailure("Invalid translation service base URL — check SUPABASE_URL environment variable")
            // Fallback URL that will fail gracefully at the network layer
            // swiftlint:disable:next force_unwrapping
            return URL(string: "https://invalid.supabase.co/functions/v1/api-v1-localization")!
        }
        return url
    }()
    public static let defaultLocale = "en"
    public static let requestTimeout: TimeInterval = 15
    public static let backgroundRefreshInterval: TimeInterval = 3600
    public static let maxRetryAttempts = 3
    public static let retryDelayBase: TimeInterval = 1.0
    public static let cacheExpirationHours: Double = 24
    public static let staleWhileRevalidateHours: Double = 2

    /// All supported locales with full metadata (matches web BFF config).
    public static let supportedLocales: [SupportedLocale] = [
        .init(
            code: "en",
            name: "English",
            nativeName: "English",
            flag: "🇬🇧",
            direction: .ltr,
            fullCode: "en-US",
            region: .global,
        ),
        .init(
            code: "cs",
            name: "Czech",
            nativeName: "Čeština",
            flag: "🇨🇿",
            direction: .ltr,
            fullCode: "cs-CZ",
            region: .europe,
        ),
        .init(
            code: "de",
            name: "German",
            nativeName: "Deutsch",
            flag: "🇩🇪",
            direction: .ltr,
            fullCode: "de-DE",
            region: .europe,
        ),
        .init(
            code: "es",
            name: "Spanish",
            nativeName: "Español",
            flag: "🇪🇸",
            direction: .ltr,
            fullCode: "es-ES",
            region: .global,
        ),
        .init(
            code: "fr",
            name: "French",
            nativeName: "Français",
            flag: "🇫🇷",
            direction: .ltr,
            fullCode: "fr-FR",
            region: .global,
        ),
        .init(
            code: "pt",
            name: "Portuguese",
            nativeName: "Português",
            flag: "🇵🇹",
            direction: .ltr,
            fullCode: "pt-PT",
            region: .global,
        ),
        .init(
            code: "ru",
            name: "Russian",
            nativeName: "Русский",
            flag: "🇷🇺",
            direction: .ltr,
            fullCode: "ru-RU",
            region: .europe,
        ),
        .init(
            code: "uk",
            name: "Ukrainian",
            nativeName: "Українська",
            flag: "🇺🇦",
            direction: .ltr,
            fullCode: "uk-UA",
            region: .europe,
        ),
        .init(
            code: "zh",
            name: "Chinese",
            nativeName: "中文",
            flag: "🇨🇳",
            direction: .ltr,
            fullCode: "zh-CN",
            region: .asia,
        ),
        .init(
            code: "hi",
            name: "Hindi",
            nativeName: "हिन्दी",
            flag: "🇮🇳",
            direction: .ltr,
            fullCode: "hi-IN",
            region: .asia,
        ),
        .init(
            code: "ar",
            name: "Arabic",
            nativeName: "العربية",
            flag: "🇸🇦",
            direction: .rtl,
            fullCode: "ar-SA",
            region: .mena,
        ),
        .init(
            code: "it",
            name: "Italian",
            nativeName: "Italiano",
            flag: "🇮🇹",
            direction: .ltr,
            fullCode: "it-IT",
            region: .europe,
        ),
        .init(
            code: "pl",
            name: "Polish",
            nativeName: "Polski",
            flag: "🇵🇱",
            direction: .ltr,
            fullCode: "pl-PL",
            region: .europe,
        ),
        .init(
            code: "nl",
            name: "Dutch",
            nativeName: "Nederlands",
            flag: "🇳🇱",
            direction: .ltr,
            fullCode: "nl-NL",
            region: .europe,
        ),
        .init(
            code: "ja",
            name: "Japanese",
            nativeName: "日本語",
            flag: "🇯🇵",
            direction: .ltr,
            fullCode: "ja-JP",
            region: .asia,
        ),
        .init(
            code: "ko",
            name: "Korean",
            nativeName: "한국어",
            flag: "🇰🇷",
            direction: .ltr,
            fullCode: "ko-KR",
            region: .asia,
        ),
        .init(
            code: "tr",
            name: "Turkish",
            nativeName: "Türkçe",
            flag: "🇹🇷",
            direction: .ltr,
            fullCode: "tr-TR",
            region: .mena,
        ),
        .init(
            code: "vi",
            name: "Vietnamese",
            nativeName: "Tiếng Việt",
            flag: "🇻🇳",
            direction: .ltr,
            fullCode: "vi-VN",
            region: .asia,
        ),
        .init(
            code: "id",
            name: "Indonesian",
            nativeName: "Bahasa Indonesia",
            flag: "🇮🇩",
            direction: .ltr,
            fullCode: "id-ID",
            region: .asia,
        ),
        .init(
            code: "th",
            name: "Thai",
            nativeName: "ไทย",
            flag: "🇹🇭",
            direction: .ltr,
            fullCode: "th-TH",
            region: .asia,
        ),
        .init(
            code: "sv",
            name: "Swedish",
            nativeName: "Svenska",
            flag: "🇸🇪",
            direction: .ltr,
            fullCode: "sv-SE",
            region: .europe,
        ),
    ]

    public static var localeCodes: [String] {
        supportedLocales.map(\.code)
    }

    public static func locale(for code: String) -> SupportedLocale? {
        supportedLocales.first { $0.code == code }
    }

    public static func locales(for region: LocaleRegion) -> [SupportedLocale] {
        supportedLocales.filter { $0.region == region }
    }
}

// MARK: - Locale Region

public enum LocaleRegion: String, Sendable, CaseIterable, Codable {
    case global
    case europe
    case asia
    case mena

    public var displayName: String {
        switch self {
        case .global: "Global"
        case .europe: "Europe"
        case .asia: "Asia Pacific"
        case .mena: "Middle East & Africa"
        }
    }
}

// MARK: - Supported Locale

public struct SupportedLocale: Sendable, Identifiable, Hashable, Codable {
    public let code: String
    public let name: String
    public let nativeName: String
    public let flag: String
    public let direction: LayoutDirection
    public let fullCode: String
    public let region: LocaleRegion

    public var id: String {
        code
    }
    public var isRTL: Bool {
        direction == .rtl
    }

    public enum LayoutDirection: String, Sendable, Codable {
        case ltr, rtl
    }

    public init(
        code: String,
        name: String,
        nativeName: String,
        flag: String,
        direction: LayoutDirection,
        fullCode: String,
        region: LocaleRegion,
    ) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.flag = flag
        self.direction = direction
        self.fullCode = fullCode
        self.region = region
    }
}

// MARK: - Translation State

public enum TranslationState: Sendable, Equatable {
    case idle
    case loading
    case ready
    case syncing
    case error(TranslationError)
    case offline(cachedAt: Date?)

    public var isReady: Bool {
        switch self {
        case .ready, .offline, .syncing: true
        default: false
        }
    }

    public var isLoading: Bool {
        switch self {
        case .loading, .syncing: true
        default: false
        }
    }
}

// MARK: - Translation Sync Stats

/// Metrics for monitoring translation performance
public struct TranslationMetrics: Sendable {
    public var cacheHits = 0
    public var cacheMisses = 0
    public var apiCalls = 0
    public var apiErrors = 0
    public var totalResponseTimeMs = 0
    public var requestCount = 0

    public var hitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0
    }

    public var avgResponseTimeMs: Double {
        requestCount > 0 ? Double(totalResponseTimeMs) / Double(requestCount) : 0
    }

    public mutating func recordCacheHit() {
        cacheHits += 1
    }

    public mutating func recordCacheMiss() {
        cacheMisses += 1
    }

    public mutating func recordApiCall(responseTimeMs: Int, success: Bool) {
        apiCalls += 1
        totalResponseTimeMs += responseTimeMs
        requestCount += 1
        if !success {
            apiErrors += 1
        }
    }

    public var summary: String {
        """
        Cache: \(cacheHits)/\(cacheHits + cacheMisses) hits (\(String(format: "%.1f", hitRate * 100))%)
        API: \(apiCalls) calls, \(apiErrors) errors, avg \(String(format: "%.0f", avgResponseTimeMs))ms
        """
    }
}

/// Statistics about translation sync state for monitoring and debugging
public struct TranslationSyncStats: Sendable {
    public let locale: String
    public let version: String?
    public let lastSyncDate: Date?
    public let translationCount: Int
    public let cachedLookupCount: Int
    public let missingKeyCount: Int
    public let isReady: Bool
    public let state: TranslationState

    public var timeSinceLastSync: TimeInterval? {
        lastSyncDate.map { Date().timeIntervalSince($0) }
    }

    public var isStale: Bool {
        guard let interval = timeSinceLastSync else { return true }
        return interval > TranslationConfig.staleWhileRevalidateHours * 3600
    }

    public var summary: String {
        """
        Locale: \(locale) (v\(version ?? "unknown"))
        Keys: \(translationCount), Cached: \(cachedLookupCount), Missing: \(missingKeyCount)
        Last sync: \(lastSyncDate?.formatted() ?? "never")
        State: \(state), Ready: \(isReady), Stale: \(isStale)
        """
    }
}

// MARK: - Translation Error

public enum TranslationError: LocalizedError, Sendable, Equatable {
    case networkError(String)
    case parseError(String)
    case syncFailed(String)
    case unsupportedLocale(String)
    case cacheCorrupted
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
    case unauthorized
    case timeout

    public var errorDescription: String? {
        switch self {
        case let .networkError(msg): "Network error: \(msg)"
        case let .parseError(msg): "Parse error: \(msg)"
        case let .syncFailed(msg): "Sync failed: \(msg)"
        case let .unsupportedLocale(locale): "Unsupported locale: \(locale)"
        case .cacheCorrupted: "Translation cache corrupted"
        case let .rateLimited(retry): "Rate limited\(retry.map { ", retry after \(Int($0))s" } ?? "")"
        case let .serverError(code): "Server error: HTTP \(code)"
        case .unauthorized: "Authentication required"
        case .timeout: "Request timed out"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited, .serverError, .timeout: true
        default: false
        }
    }

    /// User-friendly localized message
    @MainActor
    public var localizedMessage: String {
        let t = EnhancedTranslationService.shared
        switch self {
        case .networkError: return t.t("errors.network")
        case .timeout: return t.t("errors.timeout")
        case .unauthorized: return t.t("errors.unauthorized")
        default: return t.t("errors.unknown")
        }
    }
}

// MARK: - Enhanced Translation Service

@MainActor
@Observable
public final class EnhancedTranslationService: Sendable {
    public static let shared = EnhancedTranslationService()

    public private(set) var state: TranslationState = .idle
    public private(set) var currentLocale: String = TranslationConfig.defaultLocale
    public private(set) var translationRevision = 0
    public private(set) var lastSyncDate: Date?
    public private(set) var isReady = false

    private var translations: [String: Any] = [:]
    @ObservationIgnored private var flatCache: [String: String] = [:] // Flattened key cache for O(1) lookup
    private var cachedEtag: String?
    private var cachedVersion: String?
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "TranslationService")
    private var backgroundTask: Task<Void, Never>?
    private var localeObserver: NSObjectProtocol?
    private var missingKeys: Set<String> = []
    private var pendingRevalidation: Task<Void, Never>?
    private var lastReportTime = Date.distantPast

    // MARK: - Enterprise Features

    /// Task for locale sync to profile (prevents race conditions)
    private var localeSyncTask: Task<Void, Never>?

    /// In-memory cache for content translations (posts, challenges, forum posts)
    @ObservationIgnored private var contentTranslationCache: [String: (
        translations: [String: String?],
        timestamp: Date,
    )] = [:]
    private let contentCacheTTL: TimeInterval = 300 // 5 minutes

    /// Metrics for monitoring translation performance
    @ObservationIgnored public private(set) var metrics = TranslationMetrics()

    /// Supabase client for profile sync (lazy to avoid circular dependency)
    private var supabaseClient: SupabaseClient? {
        try? AuthenticationService.shared.supabase
    }

    private init() {
        self.currentLocale = Self.detectCurrentLocale()

        // Always load bundled translations first as the base/fallback
        loadBundledTranslationsSync()

        // Then merge cached translations on top (if available and matching locale)
        // This ensures new bundled keys are available even if cache doesn't have them
        mergeCachedTranslationsSync()

        // Signal that service is ready with initial locale
        // This triggers any .task(id:) modifiers that depend on translationRevision
        translationRevision += 1
        isReady = true

        setupObservers()

        // Stale-while-revalidate: serve cached, refresh in background
        Task { await revalidateIfStale() }
    }

    /// Synchronously merges cached translations on top of bundled translations.
    /// This preserves bundled keys that may be missing from the cache.
    private func mergeCachedTranslationsSync() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let cachedLocale = cache["locale"] as? String ?? "en"
        guard cachedLocale == currentLocale else {
            logger.debug("⏭️ Cache locale (\(cachedLocale)) doesn't match saved (\(self.currentLocale))")
            return
        }

        if let messages = cache["messages"] as? [String: Any], !messages.isEmpty {
            // Merge cached translations on top of bundled (cache wins for conflicts)
            translations = deepMerge(translations, messages)
            let keyCount = countKeys(in: translations)
            logger.debug("✅ Merged cached \(cachedLocale) translations: \(keyCount) total keys")
        }
        cachedVersion = cache["version"] as? String
        cachedEtag = cache["etag"] as? String
        if let dateStr = cache["lastSync"] as? String {
            lastSyncDate = ISO8601DateFormatter().date(from: dateStr)
        }
    }

    /// Synchronously loads bundled translations so they're available immediately.
    private func loadBundledTranslationsSync() {
        guard let url = Bundle.main.url(forResource: currentLocale, withExtension: "json")
            ?? Bundle.main.url(forResource: "en", withExtension: "json") else
        {
            logger.error("❌ Bundled translations not found")
            return
        }
        guard let data = try? Data(contentsOf: url),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else
        {
            logger.error("❌ Failed to parse bundled translations")
            return
        }
        translations = messages
        state = .ready
        isReady = true
        logger.debug("✅ Loaded bundled translations: \(self.countKeys(in: messages)) keys")
    }

    /// Loads bundled translations for a specific locale and returns them.
    /// Returns empty dictionary if not found (caller should handle fallback).
    private func loadBundledTranslations(for locale: String) -> [String: Any] {
        guard let url = Bundle.main.url(forResource: locale, withExtension: "json")
            ?? Bundle.main.url(forResource: "en", withExtension: "json") else
        {
            logger.warning("⚠️ Bundled translations not found for \(locale), using empty base")
            return [:]
        }
        guard let data = try? Data(contentsOf: url),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else
        {
            logger.warning("⚠️ Failed to parse bundled translations for \(locale)")
            return [:]
        }
        logger.debug("📦 Loaded bundled \(locale) translations: \(self.countKeys(in: messages)) keys")
        return messages
    }
}

// MARK: - Public API

extension EnhancedTranslationService {
    public func t(_ key: String) -> String {
        _ = translationRevision
        // 1. Fast path: check flattened cache first (O(1))
        if let cached = flatCache[key] { return cached }
        // 2. Try nested lookup
        if let value = getValue(for: key) {
            flatCache[key] = value // Cache for next time
            return value
        }
        // 3. Fall back to String Catalog for critical keys
        let localizedFromCatalog = NSLocalizedString(key, comment: "")
        if localizedFromCatalog != key { return localizedFromCatalog }
        // 4. Track missing key and return key as last resort
        trackMissingKey(key)
        return key
    }

    public func t(_ key: String, args: [String: String]) -> String {
        var result = t(key)
        for (placeholder, value) in args {
            result = result.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        return result
    }

    /// Translate with namespace prefix (e.g., t(.common, "loading") → "common.loading")
    public func t(_ namespace: TranslationNamespace, _ key: String) -> String {
        t("\(namespace.rawValue).\(key)")
    }

    /// Translate with namespace and args
    public func t(_ namespace: TranslationNamespace, _ key: String, args: [String: String]) -> String {
        t("\(namespace.rawValue).\(key)", args: args)
    }

    /// Batch translate multiple keys efficiently
    public func batch(_ keys: [String]) -> [String: String] {
        _ = translationRevision
        var results: [String: String] = [:]
        for key in keys {
            results[key] = t(key)
        }
        return results
    }

    /// Check if a translation exists for a key
    public func hasTranslation(for key: String) -> Bool {
        getValue(for: key) != nil
    }

    /// Format a date according to current locale
    public func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.dateStyle = style
        return formatter.string(from: date)
    }

    /// Format date and time
    public func formatDateTime(
        _ date: Date,
        dateStyle: DateFormatter.Style = .medium,
        timeStyle: DateFormatter.Style = .short,
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    /// Format a number according to current locale
    public func formatNumber(_ number: Double, style: NumberFormatter.Style = .decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.numberStyle = style
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    /// Format currency
    public func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    /// Format compact number (1K, 1M, etc.)
    public func formatCompact(_ number: Double) -> String {
        let absNumber = abs(number)
        let sign = number < 0 ? "-" : ""

        switch absNumber {
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.1f", absNumber / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.1f", absNumber / 1_000_000))M"
        case 1000...:
            return "\(sign)\(String(format: "%.1f", absNumber / 1000))K"
        default:
            return "\(sign)\(Int(absNumber))"
        }
    }

    /// Format relative time (e.g., "2 hours ago")
    public func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format distance (locale-aware km/mi)
    public func formatDistance(_ meters: Double) -> String {
        #if !SKIP
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: currentLocaleInfo?.fullCode ?? "en-US")
        formatter.unitOptions = MeasurementFormatter.UnitOptions.naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
        #else
        // Skip: simple fallback formatting
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
        #endif
    }

    private func trackMissingKey(_ key: String) {
        guard !key.isEmpty, !missingKeys.contains(key) else { return }
        missingKeys.insert(key)
        #if DEBUG
            logger.warning("⚠️ Missing translation: \(key)")
        #endif

        // Report to BFF in background (batch every 10 keys or 30 seconds)
        Task.detached { [weak self] in
            await self?.reportMissingKeysToBFF()
        }
    }

    /// Report missing keys to BFF for analytics
    private func reportMissingKeysToBFF() async {
        guard !missingKeys.isEmpty else { return }

        let keysToReport = Array(missingKeys)
        guard keysToReport.count >= 10 || Date().timeIntervalSince(lastReportTime) > 30 else {
            return
        }

        lastReportTime = Date()

        guard let url = URL(string: "\(TranslationConfig.baseURL.absoluteString)/translations") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ios", forHTTPHeaderField: "x-platform")
        request.setValue(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            forHTTPHeaderField: "x-app-version",
        )

        let body: [String: Any] = [
            "missing_keys": keysToReport,
            "locale": currentLocale,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "platform": "ios",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                logger.debug("✅ Reported \(keysToReport.count) missing keys to BFF")
            }
        } catch {
            logger.debug("⚠️ Failed to report missing keys: \(error.localizedDescription)")
        }
    }

    /// Get all missing keys (useful for debugging)
    public var missingTranslationKeys: Set<String> {
        missingKeys
    }

    /// Get translation key count
    public var translationCount: Int {
        countKeys(in: translations)
    }

    public func setLocale(_ locale: String) async throws {
        guard TranslationConfig.localeCodes.contains(locale) else {
            throw TranslationError.unsupportedLocale(locale)
        }
        guard locale != currentLocale else { return }

        // Cancel any pending locale sync to prevent race conditions
        localeSyncTask?.cancel()
        localeSyncTask = nil

        do {
            let newTranslations = try await fetchTranslations(locale: locale)

            UserDefaults.standard.set(locale, forKey: "app_locale_override")
            UserDefaults.standard.synchronize() // Force flush to disk to survive app termination
            currentLocale = locale
            // Load bundled translations as base, then merge server translations on top
            // This ensures bundled keys are always available as fallback
            let bundled = loadBundledTranslations(for: locale)
            translations = deepMerge(bundled, newTranslations)
            flatCache.removeAll() // Clear lookup cache
            contentTranslationCache.removeAll() // Clear content translations for new locale
            cachedEtag = nil
            cachedVersion = nil
            missingKeys.removeAll()
            saveToCache()
            state = .ready
            isReady = true
            translationRevision += 1
            NotificationCenter.default.post(name: Notification.Name.localeDidChange, object: nil, userInfo: ["locale": locale])
            logger.info("✅ Changed locale to \(locale)")

            // Sync to profile with proper tracking (fire-and-forget but tracked)
            localeSyncTask = Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    try await self.syncLocaleToProfile(locale)
                } catch {
                    self.logger.warning("⚠️ Failed to sync locale to profile: \(error.localizedDescription)")
                    // Don't rethrow - locale change succeeded locally
                }
            }
        } catch {
            logger.error("❌ Failed to load translations for \(locale): \(error.localizedDescription)")
            throw error
        }
    }

    /// Syncs the locale preference to the user's profile in Supabase
    private func syncLocaleToProfile(_ locale: String) async throws {
        guard let supabase = supabaseClient else {
            throw TranslationError.networkError("Supabase client not available")
        }

        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("profiles")
            .update(["preferred_locale": locale])
            .eq("id", value: userId)
            .execute()
        logger.debug("✅ Synced locale \(locale) to profile")
    }

    /// Loads locale preference from user's profile
    public func loadLocaleFromProfile() async {
        guard let supabase = supabaseClient else { return }

        do {
            let userId = try await supabase.auth.session.user.id
            let response: [String: String?] = try await supabase
                .from("profiles")
                .select("preferred_locale")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            if let locale = response["preferred_locale"] ?? nil,
               TranslationConfig.localeCodes.contains(locale),
               locale != currentLocale
            {
                try await setLocale(locale)
            }
        } catch {
            logger.warning("⚠️ Failed to load locale from profile: \(error.localizedDescription)")
        }
    }

    /// Syncs locale from server (Redis-backed) without re-syncing back to server
    ///
    /// This method is called after successful authentication to sync the user's
    /// locale preference from the server-side Redis cache. Unlike `setLocale()`,
    /// this does NOT write back to the profile (to avoid infinite loops).
    ///
    /// - Parameter serverLocale: The locale code from the server (e.g., "ru", "es")
    public func syncLocaleFromServer(_ serverLocale: String?) async {
        guard let locale = serverLocale,
              TranslationConfig.localeCodes.contains(locale),
              locale != currentLocale else
        {
            logger.debug("🌍 No locale sync needed (same or invalid)")
            return
        }

        logger.info("🌍 Syncing locale from server: \(self.currentLocale) → \(locale)")

        // Cancel any pending locale sync to prevent race conditions
        localeSyncTask?.cancel()
        localeSyncTask = nil

        do {
            let newTranslations = try await fetchTranslations(locale: locale)

            // Update local state (same as setLocale but without profile sync)
            UserDefaults.standard.set(locale, forKey: "app_locale_override")
            UserDefaults.standard.synchronize() // Force flush to disk to survive app termination
            currentLocale = locale
            // Load bundled translations as base, then merge server translations on top
            let bundled = loadBundledTranslations(for: locale)
            translations = deepMerge(bundled, newTranslations)
            flatCache.removeAll() // Clear lookup cache
            contentTranslationCache.removeAll() // Clear content translations for new locale
            cachedEtag = nil
            cachedVersion = nil
            missingKeys.removeAll()
            saveToCache()
            state = .ready
            isReady = true
            translationRevision += 1
            NotificationCenter.default.post(name: Notification.Name.localeDidChange, object: nil, userInfo: ["locale": locale])
            logger.info("✅ Locale synced from server: \(locale)")
        } catch {
            logger.error("❌ Failed to sync locale from server: \(error.localizedDescription)")
            // Keep current locale on failure (graceful degradation)
        }
    }

    public func resetToSystemLocale() async {
        UserDefaults.standard.removeObject(forKey: "app_locale_override")
        UserDefaults.standard.synchronize() // Force flush to disk to survive app termination

        // Sync reset to server (clear preferred_locale to prevent restore on next launch)
        Task(priority: .utility) { [weak self] in
            guard let self, let supabase = self.supabaseClient else { return }
            do {
                let userId = try await supabase.auth.session.user.id
                try await supabase
                    .from("profiles")
                    .update(["preferred_locale": AnyJSON.null])
                    .eq("id", value: userId)
                    .execute()
                self.logger.debug("Cleared locale preference on server")
            } catch {
                self.logger.warning("Failed to clear server locale: \(error.localizedDescription)")
            }
        }

        let systemLocale = Self.detectSystemLocale()
        missingKeys.removeAll()
        flatCache.removeAll()

        do {
            let newTranslations = try await fetchTranslations(locale: systemLocale)
            currentLocale = systemLocale
            // Merge server translations on top of bundled
            let bundled = loadBundledTranslations(for: systemLocale)
            translations = deepMerge(bundled, newTranslations)
            saveToCache()
        } catch {
            currentLocale = "en"
            loadBundledTranslationsSync()
        }

        cachedEtag = nil
        cachedVersion = nil
        state = .ready
        isReady = true
        translationRevision += 1
        NotificationCenter.default.post(name: Notification.Name.localeDidChange, object: nil, userInfo: ["locale": currentLocale])
    }

    /// Opens iOS Settings to the app's language settings (iOS 17+)
    /// This allows users to change the app language via iOS per-app language settings
    @MainActor
    public func openLanguageSettings() {
        #if !SKIP
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// Returns the iOS per-app language setting if set
    public var iOSPerAppLanguage: String? {
        #if !SKIP
        // iOS stores per-app language in AppleLanguages
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = languages.first
        {
            return String(first.prefix(2))
        }
        #endif
        return nil
    }

    /// Check if user has set a per-app language in iOS Settings
    public var hasIOSPerAppLanguageSetting: Bool {
        // Check if the app-specific language differs from system
        let systemLocale = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        let appLocale = iOSPerAppLanguage ?? String(systemLocale)
        return appLocale != String(systemLocale)
    }

    public func refresh() async {
        await syncFromServer(locale: currentLocale, force: true)
    }

    public var currentLocaleInfo: SupportedLocale? {
        TranslationConfig.locale(for: currentLocale)
    }

    public var isRTL: Bool {
        currentLocaleInfo?.isRTL ?? false
    }

    public var hasLocaleOverride: Bool {
        UserDefaults.standard.string(forKey: "app_locale_override") != nil
    }

    public var supportedLocales: [SupportedLocale] {
        TranslationConfig.supportedLocales
    }

    public func clearCache() {
        translations = [:]
        flatCache.removeAll()
        cachedEtag = nil
        cachedVersion = nil
        lastSyncDate = nil
        missingKeys.removeAll()
        isReady = false
        translationRevision += 1
        try? FileManager.default.removeItem(at: cacheURL)
    }

    /// Prefetch translations for multiple locales
    public func prefetch(locales: [String]) async {
        for locale in locales where locale != currentLocale {
            _ = try? await fetchTranslations(locale: locale)
        }
    }

    /// Get diagnostics info for debugging
    public var diagnostics: [String: Any] {
        [
            "locale": currentLocale,
            "state": String(describing: state),
            "isReady": isReady,
            "isRTL": isRTL,
            "translationCount": translationCount,
            "cachedLookups": flatCache.count,
            "missingKeysCount": missingKeys.count,
            "lastSync": lastSyncDate?.ISO8601Format() ?? "never",
            "hasOverride": hasLocaleOverride,
            "cachedVersion": cachedVersion ?? "none",
            "deltaSyncEnabled": true,
            "supportedLocales": TranslationConfig.localeCodes.count,
        ]
    }

    /// Get detailed sync statistics
    public var syncStats: TranslationSyncStats {
        TranslationSyncStats(
            locale: currentLocale,
            version: cachedVersion,
            lastSyncDate: lastSyncDate,
            translationCount: translationCount,
            cachedLookupCount: flatCache.count,
            missingKeyCount: missingKeys.count,
            isReady: isReady,
            state: state,
        )
    }

    /// Invalidate specific cache entries by key prefix
    public func invalidateCache(prefix: String) {
        flatCache = flatCache.filter { !$0.key.hasPrefix(prefix) }
        translationRevision += 1
    }

    /// Invalidate cache for a specific key
    public func invalidateCache(key: String) {
        flatCache.removeValue(forKey: key)
        translationRevision += 1
    }

    /// Force a full sync (ignores delta)
    public func forceFullSync() async {
        cachedVersion = nil
        cachedEtag = nil
        await syncFromServer(locale: currentLocale, force: true)
    }

    /// Context-aware translation with fallback
    public func t(_ key: String, context: String) -> String {
        // Try context-specific key first: "key.context"
        let contextKey = "\(key).\(context)"
        let result = t(contextKey)
        return result != contextKey ? result : t(key)
    }

    /// Get translation with explicit fallback
    public func t(_ key: String, fallback: String) -> String {
        let result = t(key)
        return result != key ? result : fallback
    }

    // Note: plural() method is defined in PluralRules.swift as an extension

    /// Check if current locale matches
    public func isLocale(_ code: String) -> Bool {
        currentLocale == code
    }

    /// Check if current locale is in list
    public func isLocale(in codes: [String]) -> Bool {
        codes.contains(currentLocale)
    }

    // MARK: - Dynamic Content Translation

    /// Content type for translation requests
    public enum ContentType: String, Sendable, Codable {
        case post
        case challenge
        case forumPost = "forum_post"
    }

    /// Request body for /api-v1-localization/get-translations endpoint
    private struct ContentTranslationsRequest: Codable, Sendable {
        let contentType: String
        let contentIds: [String]
        let locale: String
        let fields: [String]
    }

    /// Response from /api-v1-localization/get-translations endpoint
    public struct ContentTranslationsResponse: Codable, Sendable {
        public let success: Bool
        public let translations: [String: [String: String?]]
        public let locale: String
        public let cached: Bool?
        public let missingIds: [String]?
    }

    /// Result type for content translation requests with error visibility
    public struct ContentTranslationResult: Sendable {
        public let translations: [String: [String: String?]]
        public let error: Error?
        public var hasError: Bool {
            error != nil
        }
        public var isEmpty: Bool {
            translations.isEmpty
        }

        public init(translations: [String: [String: String?]], error: Error? = nil) {
            self.translations = translations
            self.error = error
        }

        /// Helper to get a specific field translation for a content ID
        public func translation(for id: String, field: String) -> String? {
            translations[id]?[field] ?? nil
        }
    }

    // MARK: - Content Translation Caching

    /// Get cached content translation for a specific item and field
    public func getCachedContentTranslation(id: String, field: String) -> String? {
        guard let entry = contentTranslationCache[id],
              Date().timeIntervalSince(entry.timestamp) < contentCacheTTL else
        {
            return nil
        }
        metrics.recordCacheHit()
        return entry.translations[field] ?? nil
    }

    /// Cache content translations for an item
    public func cacheContentTranslation(id: String, translations: [String: String?]) {
        contentTranslationCache[id] = (translations, Date())
    }

    /// Clear content translation cache (called on locale change)
    public func clearContentTranslationCache() {
        contentTranslationCache.removeAll()
    }

    /// Fetch translations for multiple content items directly from localization service.
    /// This is called AFTER receiving content from BFF to get translations.
    ///
    /// - Parameters:
    ///   - contentType: The type of content ("post", "challenge", "forum_post")
    ///   - contentIds: Array of content IDs to translate
    ///   - fields: Fields to translate (defaults to ["title", "description"])
    /// - Returns: ContentTranslationResult with translations and any error
    public func fetchContentTranslations(
        contentType: ContentType,
        contentIds: [String],
        fields: [String] = ["title", "description"],
    ) async -> ContentTranslationResult {
        // No translation needed for English or empty content
        guard currentLocale != "en", !contentIds.isEmpty else {
            return ContentTranslationResult(translations: [:])
        }

        // Check cache first - collect cached and uncached IDs
        var cachedTranslations: [String: [String: String?]] = [:]
        var uncachedIds: [String] = []

        for id in contentIds {
            if let entry = contentTranslationCache[id],
               Date().timeIntervalSince(entry.timestamp) < contentCacheTTL
            {
                cachedTranslations[id] = entry.translations
                metrics.recordCacheHit()
            } else {
                uncachedIds.append(id)
                metrics.recordCacheMiss()
            }
        }

        // If all translations are cached, return early
        guard !uncachedIds.isEmpty else {
            logger.debug("✅ All \(contentIds.count) content translations served from cache")
            return ContentTranslationResult(translations: cachedTranslations)
        }

        guard let supabase = supabaseClient else {
            logger.warning("⚠️ Supabase client not available for content translation")
            return ContentTranslationResult(
                translations: cachedTranslations,
                error: TranslationError.networkError("Supabase client not available"),
            )
        }

        // Batch size limit to prevent timeouts on large requests
        let batchSize = 100
        var allFetchedTranslations: [String: [String: String?]] = [:]
        var lastError: Error?

        // Chunk uncached IDs into batches
        let batches = stride(from: 0, to: uncachedIds.count, by: batchSize).map {
            Array(uncachedIds[$0 ..< min($0 + batchSize, uncachedIds.count)])
        }

        logger.debug("Fetching \(uncachedIds.count) content translations in \(batches.count) batch(es)")

        // Process batches sequentially to avoid overwhelming the server
        for batch in batches {
            let payload = ContentTranslationsRequest(
                contentType: contentType.rawValue,
                contentIds: batch,
                locale: currentLocale,
                fields: fields,
            )

            let startTime = Date()
            do {
                let response = try await LocalizationAPIService.shared.getContentTranslations(
                    contentType: contentType.rawValue,
                    contentIds: batch,
                    locale: currentLocale,
                    fields: fields
                )

                let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                metrics.recordApiCall(responseTimeMs: responseTimeMs, success: response.success)

                if response.success {
                    // Cache the new translations
                    for (id, fieldTranslations) in response.translations {
                        cacheContentTranslation(id: id, translations: fieldTranslations)
                        allFetchedTranslations[id] = fieldTranslations
                    }
                    logger
                        .debug(
                            "✅ Batch: \(response.translations.count)/\(batch.count) translations in \(responseTimeMs)ms",
                        )
                } else {
                    logger.warning("⚠️ Batch translation request returned success=false")
                    lastError = TranslationError.syncFailed("Translation request returned success=false")
                }
            } catch {
                let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                metrics.recordApiCall(responseTimeMs: responseTimeMs, success: false)
                logger.error("❌ Batch translation failed: \(error.localizedDescription)")
                lastError = error
                // Continue with next batch instead of failing entirely
            }
        }

        // Merge cached and fetched translations
        var allTranslations = cachedTranslations
        for (key, value) in allFetchedTranslations {
            allTranslations[key] = value
        }
        logger.debug("✅ Total: \(allFetchedTranslations.count) new translations fetched")
        return ContentTranslationResult(translations: allTranslations, error: lastError)
    }

    /// Convenience method to fetch translations for posts/listings
    /// Returns just the translations dictionary for backward compatibility
    public func fetchPostTranslations(
        postIds: [Int64],
        fields: [String] = ["title", "description"],
    ) async -> [String: [String: String?]] {
        let ids = postIds.map { String($0) }
        let result = await fetchContentTranslations(contentType: .post, contentIds: ids, fields: fields)
        return result.translations
    }

    /// Convenience method to fetch translations for challenges
    /// Returns just the translations dictionary for backward compatibility
    public func fetchChallengeTranslations(
        challengeIds: [Int64],
        fields: [String] = ["title", "description"],
    ) async -> [String: [String: String?]] {
        let ids = challengeIds.map { String($0) }
        let result = await fetchContentTranslations(contentType: .challenge, contentIds: ids, fields: fields)
        return result.translations
    }

    /// Convenience method to fetch translations for forum posts
    /// Returns just the translations dictionary for backward compatibility
    public func fetchForumPostTranslations(
        postIds: [Int64],
        fields: [String] = ["title", "content"],
    ) async -> [String: [String: String?]] {
        let ids = postIds.map { String($0) }
        let result = await fetchContentTranslations(contentType: .forumPost, contentIds: ids, fields: fields)
        return result.translations
    }

    /// Fetch translations with full result including error info
    public func fetchPostTranslationsWithResult(
        postIds: [Int64],
        fields: [String] = ["title", "description"],
    ) async -> ContentTranslationResult {
        let ids = postIds.map { String($0) }
        return await fetchContentTranslations(contentType: .post, contentIds: ids, fields: fields)
    }

    /// Fetch challenge translations with full result including error info
    public func fetchChallengeTranslationsWithResult(
        challengeIds: [Int64],
        fields: [String] = ["title", "description"],
    ) async -> ContentTranslationResult {
        let ids = challengeIds.map { String($0) }
        return await fetchContentTranslations(contentType: .challenge, contentIds: ids, fields: fields)
    }

    /// Fetch forum post translations with full result including error info
    public func fetchForumPostTranslationsWithResult(
        postIds: [Int64],
        fields: [String] = ["title", "content"],
    ) async -> ContentTranslationResult {
        let ids = postIds.map { String($0) }
        return await fetchContentTranslations(contentType: .forumPost, contentIds: ids, fields: fields)
    }
}

// MARK: - Private Methods

extension EnhancedTranslationService {
    /// Stale-while-revalidate: check if cache is stale and refresh in background
    private func revalidateIfStale() async {
        guard let lastSync = lastSyncDate else {
            await syncFromServer(locale: currentLocale, force: false)
            return
        }

        let staleThreshold = TranslationConfig.staleWhileRevalidateHours * 3600
        if Date().timeIntervalSince(lastSync) > staleThreshold {
            await syncFromServer(locale: currentLocale, force: false)
        }

        startBackgroundRefresh()
    }

    private static func detectCurrentLocale() -> String {
        if let override = UserDefaults.standard.string(forKey: "app_locale_override"),
           TranslationConfig.localeCodes.contains(override)
        {
            return override
        }
        return detectSystemLocale()
    }

    private static func detectSystemLocale() -> String {
        let preferred = Locale.preferredLanguages.first ?? TranslationConfig.defaultLocale
        let code = String(preferred.prefix(2))
        return TranslationConfig.localeCodes.contains(code) ? code : TranslationConfig.defaultLocale
    }

    private func syncFromServer(locale: String, force: Bool) async {
        guard pendingRevalidation == nil || force else { return }

        state = translations.isEmpty ? .loading : .syncing

        do {
            let newTranslations = try await fetchTranslationsWithRetry(locale: locale)
            // Merge server translations on top of bundled (bundled as fallback for missing keys)
            let bundled = loadBundledTranslations(for: locale)
            translations = deepMerge(bundled, newTranslations)
            flatCache.removeAll()
            saveToCache()
            state = .ready
            isReady = true
            translationRevision += 1
            logger.info("✅ Synced translations for \(locale): \(self.countKeys(in: self.translations)) keys")
        } catch let error as TranslationError {
            handleError(error)
        } catch {
            handleError(.networkError(error.localizedDescription))
        }
    }

    /// Fetch with exponential backoff retry
    private func fetchTranslationsWithRetry(locale: String) async throws -> [String: Any] {
        var lastError: Error?

        for attempt in 0 ..< TranslationConfig.maxRetryAttempts {
            do {
                return try await fetchTranslations(locale: locale)
            } catch let error as TranslationError {
                if error.isRetryable {
                    lastError = error
                    let delay = TranslationConfig.retryDelayBase * pow(2, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw error
                }
            } catch {
                throw error
            }
        }

        throw lastError ?? TranslationError.networkError("Max retries exceeded")
    }

    private func fetchTranslations(locale: String) async throws -> [String: Any] {
        // Try BFF endpoint first with delta sync (enterprise-grade)
        if let translations = try? await fetchFromBFF(locale: locale) {
            return translations
        }

        // Fallback to direct endpoint
        return try await fetchFromDirectEndpoint(locale: locale)
    }

    private func fetchFromBFF(locale: String) async throws -> [String: Any] {
        guard var components = URLComponents(url: TranslationConfig.baseURL, resolvingAgainstBaseURL: false) else {
            throw TranslationError.networkError("Failed to create URL components")
        }
        components.path = "/functions/v1/api-v1-localization/translations"

        var queryItems = [
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "platform", value: "ios"),
        ]

        // Add version for delta sync if we have cached translations
        if let version = cachedVersion, !translations.isEmpty {
            queryItems.append(URLQueryItem(name: "version", value: version))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TranslationError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TranslationConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(Bundle.main.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        if let authToken = await getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let etag = cachedEtag {
            request.setValue("\"\(etag)\"", forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else
            {
                throw TranslationError.parseError("Invalid BFF response format")
            }

            // Check if this is a delta sync response
            let isDeltaSync = httpResponse.value(forHTTPHeaderField: "X-Delta-Sync") == "true"

            if isDeltaSync, let delta = json["delta"] as? [String: Any] {
                // Apply delta updates to existing translations
                return applyDeltaUpdates(delta)
            }

            // Full sync response
            guard let responseData = json["data"] as? [String: Any],
                  let messages = responseData["messages"] as? [String: Any] else
            {
                throw TranslationError.parseError("Invalid BFF response format")
            }

            // Handle user context if present (for personalization)
            if let userContext = json["userContext"] as? [String: Any],
               let preferredLocale = userContext["preferredLocale"] as? String,
               preferredLocale != locale
            {
                logger.debug("📍 User preferred locale: \(preferredLocale)")
            }

            cachedVersion = responseData["version"] as? String
            cachedEtag = responseData["version"] as? String
            lastSyncDate = Date()
            flatCache.removeAll()

            // Log meta info
            if let meta = json["meta"] as? [String: Any] {
                let responseTime = meta["responseTimeMs"] as? Int ?? 0
                let cached = meta["cached"] as? Bool ?? false
                logger.debug("📊 BFF response: \(responseTime)ms, cached: \(cached)")
            }

            NotificationCenter.default.post(name: Notification.Name.translationsDidUpdate, object: nil)
            return messages

        case 304:
            lastSyncDate = Date()
            logger.debug("✅ Translations unchanged (304)")
            return translations

        default:
            throw TranslationError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Apply delta updates from BFF response
    private func applyDeltaUpdates(_ delta: [String: Any]) -> [String: Any] {
        var result = translations

        // Apply added keys
        if let added = delta["added"] as? [String: String] {
            for (keyPath, value) in added {
                setNestedValue(&result, keyPath: keyPath, value: value)
            }
            logger.debug("➕ Added \(added.count) translation keys")
        }

        // Apply updated keys
        if let updated = delta["updated"] as? [String: [String: Any]] {
            for (keyPath, change) in updated {
                if let newValue = change["new"] as? String {
                    setNestedValue(&result, keyPath: keyPath, value: newValue)
                }
            }
            logger.debug("🔄 Updated \(updated.count) translation keys")
        }

        // Apply deleted keys
        if let deleted = delta["deleted"] as? [String] {
            for keyPath in deleted {
                removeNestedValue(&result, keyPath: keyPath)
            }
            logger.debug("🗑️ Deleted \(deleted.count) translation keys")
        }

        // Invalidate flat cache for affected keys
        flatCache.removeAll()
        lastSyncDate = Date()

        NotificationCenter.default.post(name: Notification.Name.translationsDidUpdate, object: nil, userInfo: ["delta": true])
        return result
    }

    /// Set a nested value in the translations dictionary using dot notation
    private func setNestedValue(_ dict: inout [String: Any], keyPath: String, value: String) {
        let parts = keyPath.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return }

        if parts.count == 1 {
            dict[parts[0]] = value
            return
        }

        var current = dict
        for (index, part) in parts.dropLast().enumerated() {
            if var nested = current[part] as? [String: Any] {
                if index == parts.count - 2 {
                    if let lastPart = parts.last {
                        nested[lastPart] = value
                    }
                    current[part] = nested
                } else {
                    // Continue traversing
                    current = nested
                }
            } else {
                // Create nested structure
                var newDict: [String: Any] = [:]
                if index == parts.count - 2 {
                    if let lastPart = parts.last {
                        newDict[lastPart] = value
                    }
                }
                current[part] = newDict
            }
        }

        // Rebuild the dictionary from root
        var result = dict
        var path: [String] = []
        for part in parts.dropLast() {
            path.append(part)
        }

        // Simple approach: just set the final value
        var ref: [String: Any] = dict
        for (i, part) in parts.enumerated() {
            if i == parts.count - 1 {
                ref[part] = value
            } else {
                if ref[part] == nil {
                    ref[part] = [String: Any]()
                }
                if var nested = ref[part] as? [String: Any] {
                    if i == parts.count - 2 {
                        if let lastPart = parts.last {
                            nested[lastPart] = value
                        }
                        ref[part] = nested
                    }
                }
            }
        }
        dict = ref
    }

    /// Remove a nested value from the translations dictionary
    private func removeNestedValue(_ dict: inout [String: Any], keyPath: String) {
        let parts = keyPath.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return }

        if parts.count == 1 {
            dict.removeValue(forKey: parts[0])
            return
        }

        // For nested keys, we need to traverse and remove
        // This is a simplified implementation
        if var nested = dict[parts[0]] as? [String: Any] {
            let remainingPath = parts.dropFirst().joined(separator: ".")
            removeNestedValue(&nested, keyPath: remainingPath)
            dict[parts[0]] = nested
        }
    }

    private func fetchFromDirectEndpoint(locale: String) async throws -> [String: Any] {
        guard var components = URLComponents(url: TranslationConfig.baseURL, resolvingAgainstBaseURL: false) else {
            throw TranslationError.networkError("Failed to create URL components")
        }
        components.path = "/functions/v1/api-v1-localization"
        components.queryItems = [
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "platform", value: "ios"),
        ]

        guard let url = components.url else {
            throw TranslationError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TranslationConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(Bundle.main.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        if let authToken = await getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let etag = cachedEtag {
            request.setValue("\"\(etag)\"", forHTTPHeaderField: "If-None-Match")
        }
        if let version = cachedVersion {
            request.setValue(version, forHTTPHeaderField: "X-Version")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                cachedEtag = etag.replacingOccurrences(of: "\"", with: "")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let responseData = json["data"] as? [String: Any],
                  let messages = responseData["messages"] as? [String: Any] else
            {
                throw TranslationError.parseError("Invalid response format")
            }

            cachedVersion = responseData["version"] as? String
            lastSyncDate = Date()

            // Check if this is a delta update
            if let isDelta = responseData["delta"] as? Bool, isDelta {
                // Merge delta into existing translations
                mergeTranslations(messages)
            } else {
                flatCache.removeAll()
            }

            NotificationCenter.default.post(name: Notification.Name.translationsDidUpdate, object: nil)
            return messages

        case 304:
            lastSyncDate = Date()
            return translations

        case 401:
            throw TranslationError.unauthorized

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw TranslationError.rateLimited(retryAfter: retryAfter)

        case 500 ... 599:
            return try await fetchTranslationsFromDatabase(locale: locale)

        default:
            throw TranslationError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Fallback: fetch translations directly from Supabase database when BFF is down
    private func fetchTranslationsFromDatabase(locale: String) async throws -> [String: Any] {
        guard let supabaseURL = AppEnvironment.supabaseURL,
              let supabaseKey = AppEnvironment.supabasePublishableKey else
        {
            throw TranslationError.networkError("Supabase not configured")
        }

        guard var components = URLComponents(string: supabaseURL) else {
            throw TranslationError.networkError("Invalid Supabase URL")
        }
        components.path = "/rest/v1/translations"
        components.queryItems = [
            URLQueryItem(name: "select", value: "messages,version"),
            URLQueryItem(name: "locale", value: "eq.\(locale)"),
        ]

        guard let url = components.url else {
            throw TranslationError.networkError("Invalid database URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranslationError.networkError("Database query failed")
        }

        guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = results.first,
              let messages = first["messages"] as? [String: Any] else
        {
            if locale != "en" {
                return try await fetchTranslationsFromDatabase(locale: "en")
            }
            throw TranslationError.parseError("No translations for \(locale)")
        }

        cachedVersion = first["version"] as? String
        lastSyncDate = Date()
        return messages
    }

    private func getValue(for key: String) -> String? {
        let parts = key.split(separator: ".").map(String.init)
        var current: Any = translations
        for part in parts {
            guard let dict = current as? [String: Any], let next = dict[part] else { return nil }
            current = next
        }
        // Return string directly, or check for _value key if current is a dict
        if let str = current as? String {
            return str
        } else if let dict = current as? [String: Any], let value = dict["_value"] as? String {
            return value
        }
        return nil
    }

    /// Merge delta translations into existing translations
    private func mergeTranslations(_ delta: [String: Any]) {
        translations = deepMerge(translations, delta)
        // Invalidate affected flat cache entries
        for key in flatCache.keys {
            if getValue(for: key) != flatCache[key] {
                flatCache.removeValue(forKey: key)
            }
        }
    }

    private func deepMerge(_ base: [String: Any], _ overlay: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in overlay {
            if let overlayDict = value as? [String: Any],
               let baseDict = result[key] as? [String: Any]
            {
                result[key] = deepMerge(baseDict, overlayDict)
            } else {
                result[key] = value
            }
        }
        return result
    }

    private func getAuthToken() async -> String? {
        try? await AuthenticationService.shared.supabase.auth.session.accessToken
    }

    private func countKeys(in dict: [String: Any]) -> Int {
        dict.reduce(0) { count, pair in
            if pair.value is String { return count + 1 }
            if let nested = pair.value as? [String: Any] { return count + countKeys(in: nested) }
            return count
        }
    }

    private func handleError(_ error: TranslationError) {
        logger.error("Translation error: \(error.localizedDescription)")
        if !translations.isEmpty {
            state = .offline(cachedAt: lastSyncDate)
            isReady = true
        } else {
            state = .error(error)
        }
    }

    private func startBackgroundRefresh() {
        backgroundTask?.cancel()
        backgroundTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(TranslationConfig.backgroundRefreshInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await syncFromServer(locale: currentLocale, force: false)
            }
        }
    }

    private func setupObservers() {
        #if !SKIP
        // System locale change
        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            guard let self, !self.hasLocaleOverride else { return }
            let newLocale = Self.detectSystemLocale()
            if newLocale != self.currentLocale {
                Task {
                    self.currentLocale = newLocale
                    self.translations = [:]
                    self.flatCache.removeAll()
                    self.missingKeys.removeAll()
                    await self.syncFromServer(locale: newLocale, force: true)
                    self.translationRevision += 1
                }
            }
        }

        // Refresh when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.revalidateIfStale()
            }
        }
        #endif
    }

    #if !SKIP
    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("translations_\(currentLocale).json")
    }
    #endif

    private func saveToCache() {
        #if !SKIP
        let cache: [String: Any] = [
            "locale": currentLocale,
            "messages": translations,
            "version": cachedVersion ?? "",
            "etag": cachedEtag ?? "",
            "lastSync": ISO8601DateFormatter().string(from: Date()),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: cache) {
            try? data.write(to: cacheURL)
        }
        #endif
    }

    private func loadFromCache() {
        #if !SKIP
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (cache["locale"] as? String) == currentLocale,
              let messages = cache["messages"] as? [String: Any] else { return }

        // Merge cached translations on top of bundled (preserves bundled keys missing from cache)
        let bundled = loadBundledTranslations(for: currentLocale)
        translations = deepMerge(bundled, messages)
        cachedVersion = cache["version"] as? String
        cachedEtag = cache["etag"] as? String
        if let dateStr = cache["lastSync"] as? String {
            lastSyncDate = ISO8601DateFormatter().date(from: dateStr)
        }
        #endif
    }
}

// MARK: - Bundle Extension

extension Bundle {
    fileprivate var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let translationsDidUpdate = Notification.Name("TranslationsDidUpdate")
    public static let localeDidChange = Notification.Name("LocaleDidChange")
}

// MARK: - Translation Namespace

/// Namespaces for organized translation keys
public enum TranslationNamespace: String, Sendable {
    case common
    case auth
    case feed
    case listing
    case profile
    case settings
    case chat = "Chat"
    case map
    case forum
    case challenges = "challenge"
    case errors
    case accessibility
    case biometric
    case onboarding
    case notifications
    case reviews
    case arrangement
    case fridge
    case insights
    case help
    case emptyState = "empty_state"
    case tabs
    case app
}

// MARK: - Type Alias for Backward Compatibility

/// Type alias for backward compatibility with existing code.
/// New code should use `EnhancedTranslationService` directly.
public typealias TranslationService = EnhancedTranslationService

// MARK: - SwiftUI Environment Key

/// Environment key for EnhancedTranslationService.
/// Defined in this file to ensure it's compiled together with the service type.
@preconcurrency
private struct TranslationServiceEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: EnhancedTranslationService {
        EnhancedTranslationService.shared
    }
}

extension EnvironmentValues {
    /// Access the shared EnhancedTranslationService instance
    public var translationService: EnhancedTranslationService {
        get { self[TranslationServiceEnvironmentKey.self] }
        set { self[TranslationServiceEnvironmentKey.self] = newValue }
    }
}


#endif
