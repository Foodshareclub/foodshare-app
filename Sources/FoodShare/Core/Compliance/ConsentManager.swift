//
//  ConsentManager.swift
//  FoodShare
//
//  GDPR-compliant consent management system.
//  Tracks user consent for various data processing purposes.
//
//  Features:
//  - Granular consent categories
//  - Consent versioning for policy updates
//  - Audit trail of consent changes
//  - UI integration for consent sheets
//
//  Usage:
//  ```swift
//  // Check consent
//  if await ConsentManager.shared.hasConsent(for: .analytics) {
//      // Track analytics
//  }
//
//  // Request consent
//  await ConsentManager.shared.requestConsent(for: .marketing)
//  ```
//


#if !SKIP
import Foundation
import OSLog
import SwiftUI

// MARK: - Consent Types

public enum ConsentType: String, CaseIterable, Codable, Sendable {
    case essential // Required for app function (always granted)
    case analytics // Usage analytics and crash reporting
    case marketing // Marketing communications
    case personalization // Personalized recommendations
    case locationTracking = "location" // Background location tracking
    case thirdPartySharing = "third_party" // Sharing data with partners

    public var displayName: String {
        switch self {
        case .essential: "Essential Services"
        case .analytics: "Analytics & Improvements"
        case .marketing: "Marketing Communications"
        case .personalization: "Personalized Experience"
        case .locationTracking: "Location Services"
        case .thirdPartySharing: "Partner Sharing"
        }
    }

    @MainActor
    public func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .essential: t.t("consent.type.essential.name")
        case .analytics: t.t("consent.type.analytics.name")
        case .marketing: t.t("consent.type.marketing.name")
        case .personalization: t.t("consent.type.personalization.name")
        case .locationTracking: t.t("consent.type.location.name")
        case .thirdPartySharing: t.t("consent.type.third_party.name")
        }
    }

    public var description: String {
        switch self {
        case .essential:
            "Required for the app to function. This includes authentication, security, and core features."
        case .analytics:
            "Help us improve the app by sharing anonymous usage data and crash reports."
        case .marketing:
            "Receive updates about new features, community events, and food sharing tips."
        case .personalization:
            "Get personalized food recommendations based on your preferences and activity."
        case .locationTracking:
            "Enable location-based features like nearby listings and distance calculations."
        case .thirdPartySharing:
            "Allow us to share data with trusted partners to enhance your experience."
        }
    }

    @MainActor
    public func localizedDescription(using t: EnhancedTranslationService) -> String {
        switch self {
        case .essential: t.t("consent.type.essential.description")
        case .analytics: t.t("consent.type.analytics.description")
        case .marketing: t.t("consent.type.marketing.description")
        case .personalization: t.t("consent.type.personalization.description")
        case .locationTracking: t.t("consent.type.location.description")
        case .thirdPartySharing: t.t("consent.type.third_party.description")
        }
    }

    public var icon: String {
        switch self {
        case .essential: "shield.checkered"
        case .analytics: "chart.bar.fill"
        case .marketing: "envelope.fill"
        case .personalization: "sparkles"
        case .locationTracking: "location.fill"
        case .thirdPartySharing: "person.2.fill"
        }
    }

    public var isRequired: Bool {
        self == .essential
    }

    /// Default consent state for new users
    public var defaultValue: Bool {
        switch self {
        case .essential: true // Always required
        case .analytics: false // Opt-in
        case .marketing: false // Opt-in
        case .personalization: true // Default on, can opt-out
        case .locationTracking: false // Opt-in
        case .thirdPartySharing: false // Opt-in
        }
    }
}

// MARK: - Consent Record

public struct ConsentRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: ConsentType
    public let granted: Bool
    public let timestamp: Date
    public let policyVersion: String
    public let source: ConsentSource

    public enum ConsentSource: String, Codable, Sendable {
        case onboarding
        case settings
        case prompt
        case policyUpdate = "policy_update"
        case systemDefault = "system_default"
    }

    public init(
        type: ConsentType,
        granted: Bool,
        policyVersion: String,
        source: ConsentSource,
    ) {
        self.id = UUID()
        self.type = type
        self.granted = granted
        self.timestamp = Date()
        self.policyVersion = policyVersion
        self.source = source
    }
}

// MARK: - Consent State

public struct ConsentState: Codable, Sendable {
    public var consents: [ConsentType: Bool]
    public var policyVersion: String
    public var lastUpdated: Date
    public var history: [ConsentRecord]

    public init() {
        self.consents = [:]
        self.policyVersion = ConsentManager.currentPolicyVersion
        self.lastUpdated = Date()
        self.history = []

        // Set defaults
        for type in ConsentType.allCases {
            consents[type] = type.defaultValue
        }
    }
}

// MARK: - Consent Manager

@MainActor @Observable
public final class ConsentManager {
    public static let shared = ConsentManager()

    // Current privacy policy version - increment when policy changes
    nonisolated public static let currentPolicyVersion = "1.0"

    // MARK: - Published State

    public private(set) var state = ConsentState()
    public private(set) var isLoaded = false
    public private(set) var needsPolicyReview = false

    // MARK: - Private

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ConsentManager")
    private let storageKey = "consent_state"
    private let historyKey = "consent_history"

    private init() {}

    // MARK: - Initialization

    /// Load consent state from storage - call on app launch
    public func initialize() async {
        do {
            if let savedState: ConsentState = try await SecureStorage.shared.retrieve(
                ConsentState.self,
                forKey: storageKey,
            ) {
                state = savedState

                // Check if policy version has changed
                if savedState.policyVersion != Self.currentPolicyVersion {
                    needsPolicyReview = true
                    logger.info("Policy version changed, user needs to review")
                }
            } else {
                // First launch - set defaults
                state = ConsentState()
                await saveState()
            }

            isLoaded = true
            logger.info("Consent manager initialized")
        } catch {
            logger.error("Failed to load consent state: \(error.localizedDescription)")
            state = ConsentState()
            isLoaded = true
        }
    }

    // MARK: - Consent Checking

    /// Check if user has granted consent for a specific type
    public func hasConsent(for type: ConsentType) -> Bool {
        // Essential is always granted
        if type.isRequired { return true }

        return state.consents[type] ?? type.defaultValue
    }

    /// Check if all required consents are granted
    public func hasAllRequiredConsents() -> Bool {
        for type in ConsentType.allCases where type.isRequired {
            if !hasConsent(for: type) { return false }
        }
        return true
    }

    /// Get all current consent values
    public func getAllConsents() -> [ConsentType: Bool] {
        state.consents
    }

    // MARK: - Consent Updates

    /// Update consent for a specific type
    public func setConsent(
        _ granted: Bool,
        for type: ConsentType,
        source: ConsentRecord.ConsentSource = .settings,
    ) async {
        // Cannot change essential consent
        guard !type.isRequired else {
            logger.warning("Cannot modify essential consent")
            return
        }

        let previousValue = state.consents[type] ?? type.defaultValue

        // Only record if actually changed
        guard previousValue != granted else { return }

        // Update state
        state.consents[type] = granted
        state.lastUpdated = Date()

        // Record in history
        let record = ConsentRecord(
            type: type,
            granted: granted,
            policyVersion: Self.currentPolicyVersion,
            source: source,
        )
        state.history.append(record)

        // Persist
        await saveState()

        // Log audit event
        #if !SKIP
        await AuditLogger.shared.log(
            operation: AuditOperation.consentUpdated,
            metadata: [
                "type": type.rawValue,
                "granted": String(granted),
                "source": source.rawValue,
            ]
        )
        #endif

        // Sync to backend
        await syncConsentToBackend(type: type, granted: granted)

        logger.info("Consent updated: \(type.rawValue) = \(granted)")
    }

    /// Update multiple consents at once (e.g., from onboarding)
    public func setConsents(_ consents: [ConsentType: Bool], source: ConsentRecord.ConsentSource = .onboarding) async {
        for (type, granted) in consents {
            await setConsent(granted, for: type, source: source)
        }
    }

    /// Accept current policy version (after user reviews updated policy)
    public func acceptPolicyVersion() async {
        state.policyVersion = Self.currentPolicyVersion
        state.lastUpdated = Date()
        needsPolicyReview = false

        // Record acceptance
        let record = ConsentRecord(
            type: .essential,
            granted: true,
            policyVersion: Self.currentPolicyVersion,
            source: .policyUpdate,
        )
        state.history.append(record)

        await saveState()

        #if !SKIP
        await AuditLogger.shared.log(
            operation: AuditOperation.consentUpdated,
            metadata: ["policyVersion": Self.currentPolicyVersion]
        )
        #endif

        logger.info("Policy version \(Self.currentPolicyVersion) accepted")
    }

    /// Withdraw all non-essential consents
    public func withdrawAllConsents() async {
        for type in ConsentType.allCases where !type.isRequired {
            await setConsent(false, for: type, source: .settings)
        }

        logger.info("All optional consents withdrawn")
    }

    // MARK: - History

    /// Get consent history for a specific type
    public func getHistory(for type: ConsentType) -> [ConsentRecord] {
        state.history.filter { $0.type == type }
    }

    /// Get full consent history
    public func getFullHistory() -> [ConsentRecord] {
        state.history.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Persistence

    private func saveState() async {
        do {
            try await SecureStorage.shared.store(state, forKey: storageKey)
        } catch {
            logger.error("Failed to save consent state: \(error.localizedDescription)")
        }
    }

    private func syncConsentToBackend(type: ConsentType, granted: Bool) async {
        do {
            let supabase = SupabaseManager.shared.client

            try await supabase.rpc("update_user_consent", params: [
                "p_consent_type": type.rawValue,
                "p_granted": String(granted),
                "p_policy_version": Self.currentPolicyVersion
            ]).execute()
        } catch {
            // Non-critical - consent is stored locally
            logger.warning("Failed to sync consent to backend: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftUI Consent Sheet

public struct ConsentSettingsView: View {
    @Environment(\.translationService) private var t
    @Bindable var consentManager = ConsentManager.shared
    @Environment(\.dismiss) private var dismiss: DismissAction

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(t.t("privacy.control_data"))
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                ForEach(ConsentType.allCases, id: \.self) { type in
                    ConsentToggleRow(
                        type: type,
                        isEnabled: consentManager.hasConsent(for: type),
                        onToggle: { granted in
                            Task {
                                await consentManager.setConsent(granted, for: type)
                            }
                        },
                    )
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await consentManager.withdrawAllConsents()
                        }
                    } label: {
                        Label(t.t("privacy.withdraw_all"), systemImage: "xmark.shield")
                    }
                } footer: {
                    Text("\(t.t("privacy.last_updated")) \(consentManager.state.lastUpdated.formatted())")
                        .font(.LiquidGlass.captionSmall)
                }
            }
            .navigationTitle(t.t("privacy.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) { dismiss() }
                }
            }
        }
    }
}

struct ConsentToggleRow: View {
    @Environment(\.translationService) private var t
    let type: ConsentType
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { onToggle($0) },
        )) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: type.icon)
                    .foregroundStyle(type.isRequired ? Color.DesignSystem.brandGreen : Color.DesignSystem.textSecondary)
                    .frame(width: 24.0)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text(type.localizedDisplayName(using: t))
                            .font(.LiquidGlass.labelLarge)

                        if type.isRequired {
                            Text(t.t("common.required"))
                                .font(.LiquidGlass.captionSmall)
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.DesignSystem.brandGreen.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    Text(type.localizedDescription(using: t))
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .disabled(type.isRequired)
        .tint(Color.DesignSystem.brandGreen)
    }
}

// MARK: - Onboarding Consent Sheet

public struct OnboardingConsentView: View {
    @Environment(\.translationService) private var t
    let onComplete: ([ConsentType: Bool]) -> Void

    @State private var consents: [ConsentType: Bool] = [:]

    public init(onComplete: @escaping ([ConsentType: Bool]) -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Text(t.t("privacy.matters"))
                    .font(.LiquidGlass.displaySmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("privacy.choose_data_use"))
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)

            // Consent options
            ScrollView {
                VStack(spacing: Spacing.md) {
                    ForEach(ConsentType.allCases.filter { !$0.isRequired }, id: \.self) { type in
                        OnboardingConsentCard(
                            type: type,
                            isSelected: consents[type] ?? type.defaultValue,
                            onToggle: { selected in
                                consents[type] = selected
                            },
                        )
                    }
                }
                .padding(.horizontal)
            }

            // Actions
            VStack(spacing: Spacing.sm) {
                Button {
                    // Accept all
                    var allConsents: [ConsentType: Bool] = [:]
                    for type in ConsentType.allCases {
                        allConsents[type] = true
                    }
                    onComplete(allConsents)
                } label: {
                    Text(t.t("privacy.accept_all"))
                        .font(.LiquidGlass.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.brandGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button {
                    // Accept selected
                    var selectedConsents: [ConsentType: Bool] = [:]
                    for type in ConsentType.allCases {
                        if type.isRequired {
                            selectedConsents[type] = true
                        } else {
                            selectedConsents[type] = consents[type] ?? type.defaultValue
                        }
                    }
                    onComplete(selectedConsents)
                } label: {
                    Text(t.t("privacy.continue_selected"))
                        .font(.LiquidGlass.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.glassBackground)
                        .foregroundStyle(Color.DesignSystem.text)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.DesignSystem.background)
        .onAppear {
            // Initialize with defaults
            for type in ConsentType.allCases {
                consents[type] = type.defaultValue
            }
        }
    }
}

struct OnboardingConsentCard: View {
    @Environment(\.translationService) private var t
    let type: ConsentType
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.textSecondary)
                    .frame(width: 32.0)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(type.localizedDisplayName(using: t))
                        .font(.LiquidGlass.labelLarge)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text(type.localizedDescription(using: t))
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.textTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBorder,
                                lineWidth: isSelected ? 2 : 1,
                            ),
                    ),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Consent Settings") {
        ConsentSettingsView()
            .preferredColorScheme(.dark)
    }

    #Preview("Onboarding Consent") {
        OnboardingConsentView { consents in
            print("Consents: \(consents)")
        }
        .preferredColorScheme(.dark)
    }
#endif

#endif
