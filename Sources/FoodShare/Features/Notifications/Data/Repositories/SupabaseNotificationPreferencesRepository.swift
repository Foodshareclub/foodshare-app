// MARK: - SupabaseNotificationPreferencesRepository.swift
// Enterprise Notification Preferences Repository Implementation
// FoodShare iOS - Clean Architecture Data Layer

import Foundation
import Supabase

// MARK: - Supabase Implementation

/// Production implementation of NotificationPreferencesRepository
/// Communicates with the api-v1-notification-preferences Edge Function
@MainActor
public final class SupabaseNotificationPreferencesRepository: NotificationPreferencesRepository, @unchecked Sendable {

    // MARK: - Properties

    private let client: SupabaseClient
    private let functionName = "api-v1-notification-preferences"

    /// Local cache for optimistic updates
    private var cachedPreferences: NotificationPreferences?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 60 // 1 minute cache

    // MARK: - Initialization

    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Private Helpers

    private var currentUserId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }

    private func requireAuth() async throws -> UUID {
        guard let userId = await currentUserId else {
            throw NotificationPreferencesError.notAuthenticated
        }
        return userId
    }

    /// Make authenticated request to Edge Function
    private func invokeFunction<T: Decodable>(
        method: String = "GET",
        queryParams: [String: String]? = nil,
        body: (any Encodable)? = nil,
    ) async throws -> T {
        _ = try await requireAuth()

        // Build URL with query parameters
        var urlString = functionName
        if let params = queryParams, !params.isEmpty {
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        do {
            let response: T

            switch method {
            case "GET":
                response = try await client.functions.invoke(
                    urlString,
                    options: FunctionInvokeOptions(
                        method: .get,
                    ),
                )

            case "PUT":
                let bodyData: Data? = if let body {
                    try JSONEncoder().encode(AnyEncodable(body))
                } else {
                    nil
                }
                response = try await client.functions.invoke(
                    urlString,
                    options: FunctionInvokeOptions(
                        method: .put,
                        body: bodyData,
                    ),
                )

            case "POST":
                let bodyData: Data? = if let body {
                    try JSONEncoder().encode(AnyEncodable(body))
                } else {
                    nil
                }
                response = try await client.functions.invoke(
                    urlString,
                    options: FunctionInvokeOptions(
                        method: .post,
                        body: bodyData,
                    ),
                )

            case "DELETE":
                response = try await client.functions.invoke(
                    urlString,
                    options: FunctionInvokeOptions(
                        method: .delete,
                    ),
                )

            default:
                throw NotificationPreferencesError.validationError(message: "Invalid HTTP method")
            }

            return response

        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch {
            throw NotificationPreferencesError.networkError(underlying: error)
        }
    }

    private func mapFunctionsError(_ error: FunctionsError) -> NotificationPreferencesError {
        switch error {
        case let .httpError(code, _):
            switch code {
            case 401:
                .notAuthenticated
            case 429:
                .rateLimited(retryAfter: nil)
            case 400 ... 499:
                .validationError(message: "Invalid request")
            default:
                .serverError(message: "Server error (code: \(code))")
            }
        case .relayError:
            .networkError(underlying: error)
        }
    }

    // MARK: - Fetch Operations

    public func fetchPreferences() async throws -> NotificationPreferences {
        // Check cache validity
        if let cached = cachedPreferences,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValiditySeconds
        {
            return cached
        }

        let response: PreferencesAPIResponse = try await invokeFunction(method: "GET")

        let preferences = mapAPIResponse(response)
        cachedPreferences = preferences
        lastFetchTime = Date()

        return preferences
    }

    // MARK: - Update Operations

    public func updateSettings(_ settings: UpdateSettingsRequest) async throws -> NotificationGlobalSettings {
        let response: SettingsUpdateResponse = try await invokeFunction(
            method: "PUT",
            body: settings,
        )

        // Invalidate cache
        cachedPreferences = nil

        return mapSettingsResponse(response)
    }

    public func updatePreference(_ preference: CategoryPreference) async throws {
        let request = UpdatePreferenceRequest(preference: preference)

        let _: PreferenceUpdateResponse = try await invokeFunction(
            method: "PUT",
            queryParams: ["action": "preference"],
            body: request,
        )

        // Update local cache optimistically
        if var cached = cachedPreferences {
            var categoryPrefs = cached.preferences[preference.category.rawValue] ?? [:]
            categoryPrefs[preference.channel.rawValue] = NotificationPreferences.CategoryPreferenceData(
                enabled: preference.enabled,
                frequency: preference.frequency.rawValue,
            )
            cached.preferences[preference.category.rawValue] = categoryPrefs
            cachedPreferences = cached
        }
    }

    public func updatePreferences(_ preferences: [CategoryPreference]) async throws {
        // Batch update - make concurrent requests
        try await withThrowingTaskGroup(of: Void.self) { group in
            for preference in preferences {
                group.addTask {
                    try await self.updatePreference(preference)
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Do Not Disturb

    public func enableDND(_ request: EnableDNDRequest) async throws -> DoNotDisturb {
        let response: DNDResponse = try await invokeFunction(
            method: "POST",
            queryParams: ["action": "dnd"],
            body: request,
        )

        let dnd = DoNotDisturb(
            enabled: response.dnd_enabled,
            until: response.dnd_until.flatMap { ISO8601DateFormatter().date(from: $0) },
        )

        // Update cache
        cachedPreferences?.settings.dnd = dnd

        return dnd
    }

    public func disableDND() async throws {
        let _: DNDResponse = try await invokeFunction(
            method: "DELETE",
            queryParams: ["action": "dnd"],
        )

        // Update cache
        cachedPreferences?.settings.dnd = DoNotDisturb(enabled: false, until: nil)
    }

    // MARK: - Phone Verification

    public func initiatePhoneVerification(phoneNumber: String) async throws {
        let request = PhoneVerificationRequest(phone_number: phoneNumber, verification_code: nil)

        let _: PhoneVerificationResponse = try await invokeFunction(
            method: "POST",
            queryParams: ["action": "phone"],
            body: request,
        )
    }

    public func verifyPhone(phoneNumber: String, code: String) async throws -> Bool {
        let request = PhoneVerificationRequest(phone_number: phoneNumber, verification_code: code)

        let response: PhoneVerificationResponse = try await invokeFunction(
            method: "POST",
            queryParams: ["action": "phone"],
            body: request,
        )

        if response.verified == true {
            // Update cache
            cachedPreferences?.settings.phoneVerified = true
            cachedPreferences?.settings.phoneNumber = phoneNumber
            return true
        }

        throw NotificationPreferencesError.phoneVerificationFailed
    }

    // MARK: - Response Mapping

    private func mapAPIResponse(_ response: PreferencesAPIResponse) -> NotificationPreferences {
        var preferences = NotificationPreferences()

        // Map settings
        if let settings = response.settings {
            preferences.settings = NotificationGlobalSettings(
                pushEnabled: settings.push_enabled ?? true,
                emailEnabled: settings.email_enabled ?? true,
                smsEnabled: settings.sms_enabled ?? false,
                phoneNumber: settings.phone_number,
                phoneVerified: settings.phone_verified ?? false,
                quietHours: QuietHours(
                    enabled: settings.quiet_hours?.enabled ?? false,
                    start: settings.quiet_hours?.start ?? "22:00",
                    end: settings.quiet_hours?.end ?? "08:00",
                    timezone: settings.quiet_hours?.timezone ?? TimeZone.current.identifier,
                ),
                dnd: DoNotDisturb(
                    enabled: settings.dnd?.enabled ?? false,
                    until: settings.dnd?.until.flatMap { ISO8601DateFormatter().date(from: $0) },
                ),
                digest: DigestSettings(
                    dailyEnabled: settings.digest?.daily_enabled ?? true,
                    dailyTime: settings.digest?.daily_time ?? "09:00",
                    weeklyEnabled: settings.digest?.weekly_enabled ?? true,
                    weeklyDay: settings.digest?.weekly_day ?? 1,
                ),
            )
        }

        // Map category preferences
        if let categoryPrefs = response.preferences {
            for (category, channels) in categoryPrefs {
                var channelPrefs: [String: NotificationPreferences.CategoryPreferenceData] = [:]
                for (channel, data) in channels {
                    channelPrefs[channel] = NotificationPreferences.CategoryPreferenceData(
                        enabled: data.enabled,
                        frequency: data.frequency,
                    )
                }
                preferences.preferences[category] = channelPrefs
            }
        }

        return preferences
    }

    private func mapSettingsResponse(_ response: SettingsUpdateResponse) -> NotificationGlobalSettings {
        NotificationGlobalSettings(
            pushEnabled: response.push_enabled ?? true,
            emailEnabled: response.email_enabled ?? true,
            smsEnabled: response.sms_enabled ?? false,
            phoneNumber: response.phone_number,
            phoneVerified: response.phone_verified ?? false,
            quietHours: QuietHours(
                enabled: response.quiet_hours?.enabled ?? false,
                start: response.quiet_hours?.start ?? "22:00",
                end: response.quiet_hours?.end ?? "08:00",
                timezone: response.quiet_hours?.timezone ?? TimeZone.current.identifier,
            ),
            dnd: DoNotDisturb(
                enabled: response.dnd?.enabled ?? false,
                until: response.dnd?.until.flatMap { ISO8601DateFormatter().date(from: $0) },
            ),
            digest: DigestSettings(
                dailyEnabled: response.digest?.daily_enabled ?? true,
                dailyTime: response.digest?.daily_time ?? "09:00",
                weeklyEnabled: response.digest?.weekly_enabled ?? true,
                weeklyDay: response.digest?.weekly_day ?? 1,
            ),
        )
    }
}

// MARK: - API Response Types

private struct PreferencesAPIResponse: Decodable {
    let settings: SettingsData?
    let preferences: [String: [String: PreferenceData]]?
    let categories: [CategoryData]?
    let channels: [ChannelData]?
    let frequencies: [FrequencyData]?

    struct SettingsData: Decodable {
        let push_enabled: Bool?
        let email_enabled: Bool?
        let sms_enabled: Bool?
        let phone_number: String?
        let phone_verified: Bool?
        let quiet_hours: QuietHoursData?
        let dnd: DNDData?
        let digest: DigestData?
    }

    struct QuietHoursData: Decodable {
        let enabled: Bool?
        let start: String?
        let end: String?
        let timezone: String?
    }

    struct DNDData: Decodable {
        let enabled: Bool?
        let until: String?
    }

    struct DigestData: Decodable {
        let daily_enabled: Bool?
        let daily_time: String?
        let weekly_enabled: Bool?
        let weekly_day: Int?
    }

    struct PreferenceData: Decodable {
        let enabled: Bool
        let frequency: String
    }

    struct CategoryData: Decodable {
        let key: String
        let label: String
        let description: String
    }

    struct ChannelData: Decodable {
        let key: String
        let label: String
        let description: String
    }

    struct FrequencyData: Decodable {
        let key: String
        let label: String
        let description: String
    }
}

private struct SettingsUpdateResponse: Decodable {
    let push_enabled: Bool?
    let email_enabled: Bool?
    let sms_enabled: Bool?
    let phone_number: String?
    let phone_verified: Bool?
    let quiet_hours: QuietHoursData?
    let dnd: DNDData?
    let digest: DigestData?

    struct QuietHoursData: Decodable {
        let enabled: Bool?
        let start: String?
        let end: String?
        let timezone: String?
    }

    struct DNDData: Decodable {
        let enabled: Bool?
        let until: String?
    }

    struct DigestData: Decodable {
        let daily_enabled: Bool?
        let daily_time: String?
        let weekly_enabled: Bool?
        let weekly_day: Int?
    }
}

private struct PreferenceUpdateResponse: Decodable {
    let success: Bool
    let error: String?
}

private struct DNDResponse: Decodable {
    let dnd_enabled: Bool
    let dnd_until: String?
}

private struct PhoneVerificationRequest: Encodable {
    let phone_number: String
    let verification_code: String?
}

private struct PhoneVerificationResponse: Decodable {
    let phone_saved: Bool?
    let verified: Bool?
    let verification_required: Bool?
    let message: String?
}

// MARK: - Type Erasure Helper

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        self.encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
