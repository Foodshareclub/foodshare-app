//
//  GDPRExportService.swift
//  FoodShare
//
//  GDPR Article 20 - Right to Data Portability
//  Exports all user data in a machine-readable format (JSON).
//
//  Collects data from:
//  - Supabase backend (profile, posts, messages, etc.)
//  - Local storage (preferences, cached data)
//  - Keychain (non-sensitive metadata)
//
//  Usage:
//  ```swift
//  let url = try await GDPRExportService.shared.exportUserData()
//  // Share or save the exported file
//  ```
//


#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Export Configuration

public struct GDPRExportConfiguration: Sendable {
    public let includeProfile: Bool
    public let includeListings: Bool
    public let includeMessages: Bool
    public let includeActivity: Bool
    public let includePreferences: Bool
    public let includeLocalCache: Bool
    public let format: ExportFormat

    public enum ExportFormat: String, Sendable {
        case json
        case csv // Future support
    }

    public init(
        includeProfile: Bool = true,
        includeListings: Bool = true,
        includeMessages: Bool = true,
        includeActivity: Bool = true,
        includePreferences: Bool = true,
        includeLocalCache: Bool = true,
        format: ExportFormat = .json,
    ) {
        self.includeProfile = includeProfile
        self.includeListings = includeListings
        self.includeMessages = includeMessages
        self.includeActivity = includeActivity
        self.includePreferences = includePreferences
        self.includeLocalCache = includeLocalCache
        self.format = format
    }

    public static let full = GDPRExportConfiguration()

    public static let minimal = GDPRExportConfiguration(
        includeActivity: false,
        includeLocalCache: false,
    )
}

// MARK: - Export Data Structures

public struct GDPRExportData: Codable, Sendable {
    public let exportMetadata: ExportMetadata
    public let profile: ProfileData?
    public let listings: [ListingData]?
    public let messages: [MessageData]?
    public let activity: [ActivityData]?
    public let preferences: PreferencesData?
    public let localData: LocalData?

    public struct ExportMetadata: Codable, Sendable {
        public let exportDate: Date
        public let exportVersion: String
        public let userId: String
        public let requestedSections: [String]
        public let appVersion: String
        public let platform: String
    }

    public struct ProfileData: Codable, Sendable {
        public let id: String
        public let email: String?
        public let displayName: String?
        public let bio: String?
        public let avatarUrl: String?
        public let phoneNumber: String?
        public let location: LocationData?
        public let createdAt: Date?
        public let updatedAt: Date?
        public let isVerified: Bool?
        public let badges: [String]?

        public struct LocationData: Codable, Sendable {
            public let latitude: Double?
            public let longitude: Double?
            public let city: String?
            public let country: String?
        }
    }

    public struct ListingData: Codable, Sendable {
        public let id: Int
        public let title: String
        public let description: String?
        public let postType: String
        public let images: [String]?
        public let location: String?
        public let pickupTime: String?
        public let status: String
        public let viewCount: Int
        public let likeCount: Int
        public let createdAt: Date
        public let expiresAt: Date?
    }

    public struct MessageData: Codable, Sendable {
        public let conversationId: String
        public let participantIds: [String]
        public let messages: [SingleMessage]

        public struct SingleMessage: Codable, Sendable {
            public let id: String
            public let content: String
            public let senderId: String
            public let createdAt: Date
            public let isRead: Bool
        }
    }

    public struct ActivityData: Codable, Sendable {
        public let eventType: String
        public let eventData: [String: String]?
        public let createdAt: Date
    }

    public struct PreferencesData: Codable, Sendable {
        public let notificationsEnabled: Bool
        public let emailNotifications: Bool
        public let pushNotifications: Bool
        public let searchRadius: Double?
        public let defaultLocation: ProfileData.LocationData?
        public let theme: String?
        public let language: String?
        public let consentHistory: [ConsentRecord]?

        public struct ConsentRecord: Codable, Sendable {
            public let consentType: String
            public let granted: Bool
            public let timestamp: Date
            public let version: String?
        }
    }

    public struct LocalData: Codable, Sendable {
        public let cachedListingsCount: Int
        public let savedSearches: [String]?
        public let recentSearches: [String]?
        public let draftListings: Int
        public let offlineQueueCount: Int
        public let lastSyncDate: Date?
    }
}

// MARK: - Export Progress

public struct GDPRExportProgress: Sendable {
    public let currentStep: String
    public let stepsCompleted: Int
    public let totalSteps: Int
    public let percentComplete: Double

    public var isComplete: Bool {
        stepsCompleted >= totalSteps
    }
}

// MARK: - GDPR Export Service

public actor GDPRExportService {
    public nonisolated static let shared: GDPRExportService = {
        GDPRExportService(supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase })
    }()

    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "GDPRExport")
    private let exportVersion = "1.0"

    // Progress tracking
    private var progressContinuation: AsyncStream<GDPRExportProgress>.Continuation?

    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Public API

    /// Export all user data to a JSON file
    /// Returns the URL of the exported file
    public func exportUserData(
        configuration: GDPRExportConfiguration = .full,
    ) async throws -> URL {
        logger.info("Starting GDPR data export")

        let steps = calculateSteps(for: configuration)
        var completedSteps = 0

        func updateProgress(_ step: String) {
            completedSteps += 1
            let progress = GDPRExportProgress(
                currentStep: step,
                stepsCompleted: completedSteps,
                totalSteps: steps,
                percentComplete: Double(completedSteps) / Double(steps) * 100,
            )
            progressContinuation?.yield(progress)
        }

        // Get current user ID
        guard let userId = try? await supabase.auth.session.user.id.uuidString else {
            throw GDPRExportError.notAuthenticated
        }

        // Collect data from each source
        var profile: GDPRExportData.ProfileData?
        var listings: [GDPRExportData.ListingData]?
        var messages: [GDPRExportData.MessageData]?
        var activity: [GDPRExportData.ActivityData]?
        var preferences: GDPRExportData.PreferencesData?
        var localData: GDPRExportData.LocalData?

        // Profile data
        if configuration.includeProfile {
            updateProgress("Exporting profile data")
            profile = try await fetchProfileData(userId: userId, supabase: supabase)
        }

        // Listings data
        if configuration.includeListings {
            updateProgress("Exporting listings")
            listings = try await fetchListingsData(userId: userId, supabase: supabase)
        }

        // Messages data
        if configuration.includeMessages {
            updateProgress("Exporting messages")
            messages = try await fetchMessagesData(userId: userId, supabase: supabase)
        }

        // Activity data
        if configuration.includeActivity {
            updateProgress("Exporting activity history")
            activity = try await fetchActivityData(userId: userId, supabase: supabase)
        }

        // Preferences
        if configuration.includePreferences {
            updateProgress("Exporting preferences")
            preferences = await fetchPreferencesData()
        }

        // Local cache data
        if configuration.includeLocalCache {
            updateProgress("Exporting local data")
            localData = await fetchLocalData()
        }

        // Build export structure
        updateProgress("Generating export file")

        let requestedSections = buildRequestedSections(configuration)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        let exportData = GDPRExportData(
            exportMetadata: GDPRExportData.ExportMetadata(
                exportDate: Date(),
                exportVersion: exportVersion,
                userId: userId,
                requestedSections: requestedSections,
                appVersion: appVersion,
                platform: "iOS",
            ),
            profile: profile,
            listings: listings,
            messages: messages,
            activity: activity,
            preferences: preferences,
            localData: localData,
        )

        // Write to file
        let fileURL = try await writeExportFile(data: exportData, format: configuration.format)

        updateProgress("Export complete")
        progressContinuation?.finish()

        logger.info("GDPR export completed: \(fileURL.lastPathComponent)")

        // TODO: Re-enable when AuditLogger is updated with GDPR events
        // await AuditLogger.shared.log(.gdprDataExport(sections: requestedSections))

        return fileURL
    }

    /// Stream export progress updates
    public func progressStream() -> AsyncStream<GDPRExportProgress> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }

    /// Request account deletion (GDPR Article 17 - Right to Erasure)
    public func requestAccountDeletion(reason: String?) async throws {
        logger.info("Account deletion requested")

        // Call backend RPC to initiate deletion
        _ = try await supabase.rpc("request_account_deletion", params: [
            "p_reason": reason ?? "User requested"
        ]).execute()

        // TODO: Re-enable when AuditLogger is updated with GDPR events
        // await AuditLogger.shared.log(.accountDeletionRequested(reason: reason))

        logger.info("Account deletion request submitted")
    }

    // MARK: - Data Fetching

    private func fetchProfileData(userId: String, supabase: Supabase.SupabaseClient) async throws -> GDPRExportData.ProfileData {
        let response = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct ProfileRow: Decodable {
            let id: String
            let email: String?
            let displayName: String?
            let bio: String?
            let avatarUrl: String?
            let phoneNumber: String?
            let latitude: Double?
            let longitude: Double?
            let city: String?
            let country: String?
            let createdAt: Date?
            let updatedAt: Date?
            let isVerified: Bool?
        }

        let row = try decoder.decode(ProfileRow.self, from: response.data)

        return GDPRExportData.ProfileData(
            id: row.id,
            email: row.email,
            displayName: row.displayName,
            bio: row.bio,
            avatarUrl: row.avatarUrl,
            phoneNumber: row.phoneNumber,
            location: GDPRExportData.ProfileData.LocationData(
                latitude: row.latitude,
                longitude: row.longitude,
                city: row.city,
                country: row.country,
            ),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            isVerified: row.isVerified,
            badges: nil, // Would fetch from badges table
        )
    }

    private func fetchListingsData(
        userId: String,
        supabase: Supabase.SupabaseClient,
    ) async throws -> [GDPRExportData.ListingData] {
        let response = try await supabase
            .from("posts")
            .select()
            .eq("profile_id", value: userId)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct ListingRow: Decodable {
            let id: Int
            let postName: String
            let postDescription: String?
            let postType: String
            let images: [String]?
            let postAddress: String?
            let pickupTime: String?
            let isActive: Bool
            let postViews: Int
            let postLikeCounter: Int
            let createdAt: Date
            let expiresAt: Date?
        }

        let rows = try decoder.decode([ListingRow].self, from: response.data)

        return rows.map { row in
            GDPRExportData.ListingData(
                id: row.id,
                title: row.postName,
                description: row.postDescription,
                postType: row.postType,
                images: row.images,
                location: row.postAddress,
                pickupTime: row.pickupTime,
                status: row.isActive ? "active" : "inactive",
                viewCount: row.postViews,
                likeCount: row.postLikeCounter,
                createdAt: row.createdAt,
                expiresAt: row.expiresAt,
            )
        }
    }

    private func fetchMessagesData(
        userId: String,
        supabase: Supabase.SupabaseClient,
    ) async throws -> [GDPRExportData.MessageData] {
        // Fetch conversations where user is a participant
        let response = try await supabase
            .rpc("get_user_messages_export", params: ["p_user_id": userId])
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct ConversationExport: Decodable {
            let conversationId: String
            let participantIds: [String]
            let messages: [MessageExport]

            struct MessageExport: Decodable {
                let id: String
                let content: String
                let senderId: String
                let createdAt: Date
                let isRead: Bool
            }
        }

        do {
            let conversations = try decoder.decode([ConversationExport].self, from: response.data)
            return conversations.map { conv in
                GDPRExportData.MessageData(
                    conversationId: conv.conversationId,
                    participantIds: conv.participantIds,
                    messages: conv.messages.map { msg in
                        GDPRExportData.MessageData.SingleMessage(
                            id: msg.id,
                            content: msg.content,
                            senderId: msg.senderId,
                            createdAt: msg.createdAt,
                            isRead: msg.isRead,
                        )
                    },
                )
            }
        } catch {
            // RPC might not exist yet
            logger.warning("Messages export RPC not available: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchActivityData(
        userId: String,
        supabase: Supabase.SupabaseClient,
    ) async throws -> [GDPRExportData.ActivityData] {
        let response = try await supabase
            .from("user_events")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1000) // Reasonable limit
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct ActivityRow: Decodable {
            let eventType: String
            let eventData: [String: String]?
            let createdAt: Date
        }

        do {
            let rows = try decoder.decode([ActivityRow].self, from: response.data)
            return rows.map { row in
                GDPRExportData.ActivityData(
                    eventType: row.eventType,
                    eventData: row.eventData,
                    createdAt: row.createdAt,
                )
            }
        } catch {
            // Table might not exist
            logger.warning("Activity export failed: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchPreferencesData() async -> GDPRExportData.PreferencesData {
        let defaults = UserDefaults.standard

        // Fetch consent history from secure storage
        var consentHistory: [GDPRExportData.PreferencesData.ConsentRecord]?
        if let history: [ConsentRecord] = try? await SecureStorage.shared.retrieve(
            [ConsentRecord].self,
            forKey: "consent_history",
        ) {
            consentHistory = history.map { record in
                GDPRExportData.PreferencesData.ConsentRecord(
                    consentType: record.type.rawValue,
                    granted: record.granted,
                    timestamp: record.timestamp,
                    version: record.policyVersion,
                )
            }
        }

        return GDPRExportData.PreferencesData(
            notificationsEnabled: defaults.bool(forKey: "notifications_enabled"),
            emailNotifications: defaults.bool(forKey: "email_notifications"),
            pushNotifications: defaults.bool(forKey: "push_notifications"),
            searchRadius: defaults.object(forKey: "search_radius") as? Double,
            defaultLocation: nil, // Would fetch from location service
            theme: defaults.string(forKey: "app_theme"),
            language: defaults.string(forKey: "app_language") ?? Locale.current.language.languageCode?.identifier,
            consentHistory: consentHistory,
        )
    }

    private func fetchLocalData() async -> GDPRExportData.LocalData {
        let defaults = UserDefaults.standard

        // Count cached data
        let cachedListingsCount = (
            try? FileManager.default
                .contentsOfDirectory(atPath: NSTemporaryDirectory())
                .count(where: { $0.hasPrefix("listing_cache_") }),
        ) ?? 0

        let savedSearches = defaults.stringArray(forKey: "saved_searches")
        let recentSearches = defaults.stringArray(forKey: "recent_searches")
        let draftListings = defaults.integer(forKey: "draft_listings_count")
        let offlineQueueCount = await AppStateRestoration.shared.getRestorationPendingOperations().count
        let lastSyncDate = defaults.object(forKey: "last_sync_date") as? Date

        return GDPRExportData.LocalData(
            cachedListingsCount: cachedListingsCount,
            savedSearches: savedSearches,
            recentSearches: recentSearches,
            draftListings: draftListings,
            offlineQueueCount: offlineQueueCount,
            lastSyncDate: lastSyncDate,
        )
    }

    // MARK: - File Writing

    private func writeExportFile(
        data: GDPRExportData,
        format: GDPRExportConfiguration.ExportFormat,
    ) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(data)

        // Create export directory
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gdpr_exports", isDirectory: true)

        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "foodshare_data_export_\(timestamp).json"

        let fileURL = exportDir.appendingPathComponent(filename)

        try jsonData.write(to: fileURL)

        return fileURL
    }

    // MARK: - Helpers

    private func calculateSteps(for config: GDPRExportConfiguration) -> Int {
        var steps = 1 // Final generation step

        if config.includeProfile { steps += 1 }
        if config.includeListings { steps += 1 }
        if config.includeMessages { steps += 1 }
        if config.includeActivity { steps += 1 }
        if config.includePreferences { steps += 1 }
        if config.includeLocalCache { steps += 1 }

        return steps
    }

    private func buildRequestedSections(_ config: GDPRExportConfiguration) -> [String] {
        var sections: [String] = []

        if config.includeProfile { sections.append("profile") }
        if config.includeListings { sections.append("listings") }
        if config.includeMessages { sections.append("messages") }
        if config.includeActivity { sections.append("activity") }
        if config.includePreferences { sections.append("preferences") }
        if config.includeLocalCache { sections.append("local_data") }

        return sections
    }
}

// MARK: - Errors

public enum GDPRExportError: LocalizedError, Sendable {
    case notAuthenticated
    case exportFailed(String)
    case fileWriteError(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "You must be logged in to export your data"
        case let .exportFailed(reason):
            "Export failed: \(reason)"
        case let .fileWriteError(reason):
            "Failed to write export file: \(reason)"
        }
    }
}


#endif
