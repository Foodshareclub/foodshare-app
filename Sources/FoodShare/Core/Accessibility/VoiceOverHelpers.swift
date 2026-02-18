//
//  VoiceOverHelpers.swift
//  Foodshare
//
//  VoiceOver accessibility helpers for enterprise-grade screen reader support
//  Provides custom labels, hints, actions, and announcement utilities
//


#if !SKIP
import SwiftUI

// MARK: - Accessibility Label Builder

/// Builds comprehensive accessibility labels for complex views
@resultBuilder
public struct AccessibilityLabelBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }

    public static func buildEither(first component: String) -> String {
        component
    }

    public static func buildEither(second component: String) -> String {
        component
    }

    public static func buildArray(_ components: [String]) -> String {
        components.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Accessibility Description

/// Provides formatted accessibility descriptions for common data types
public enum AccessibilityDescription {

    // MARK: - Food Items

    /// Creates a localized accessibility label for a food item
    @MainActor
    public static func foodItem(
        name: String,
        category: String?,
        distance: String?,
        expiresIn: String?,
        isFree: Bool = true,
        using t: EnhancedTranslationService,
    ) -> String {
        var components: [String] = [name]

        if let category {
            components.append(category)
        }

        if isFree {
            components.append(t.t("accessibility.free"))
        }

        if let distance {
            components.append(distance + " " + t.t("accessibility.away"))
        }

        if let expiresIn {
            components.append(t.t("accessibility.expires") + " " + expiresIn)
        }

        return components.joined(separator: ", ")
    }

    /// Creates a localized accessibility hint for a food item card
    @MainActor
    public static func foodItemHint(hasClaimAction: Bool = true, using t: EnhancedTranslationService) -> String {
        if hasClaimAction {
            return t.t("accessibility.food_item_claim_hint")
        }
        return t.t("accessibility.food_item_view_hint")
    }

    // MARK: - User Profiles

    /// Creates an accessibility label for a user profile
    public static func userProfile(
        name: String,
        itemsShared: Int,
        rating: Double?,
        isVerified: Bool = false,
    ) -> String {
        var components: [String] = [name]

        if isVerified {
            components.append("verified user")
        }

        components.append("\(itemsShared) items shared")

        if let rating {
            let formattedRating = String(format: "%.1f", rating)
            components.append("\(formattedRating) star rating")
        }

        return components.joined(separator: ", ")
    }

    /// Creates a localized accessibility label for a user profile
    @MainActor
    public static func userProfile(
        name: String,
        itemsShared: Int,
        rating: Double?,
        isVerified: Bool = false,
        using t: EnhancedTranslationService,
    ) -> String {
        var components: [String] = [name]

        if isVerified {
            components.append(t.t("accessibility.verified_user"))
        }

        components.append(t.t("accessibility.items_shared", args: ["count": String(itemsShared)]))

        if let rating {
            let formattedRating = String(format: "%.1f", rating)
            components.append(t.t("accessibility.star_rating", args: ["rating": formattedRating]))
        }

        return components.joined(separator: ", ")
    }

    // MARK: - Dates & Times

    /// Creates a human-readable date description
    public static func date(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Creates a relative time description (e.g., "2 hours ago")
    public static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Creates an expiration description
    public static func expiration(date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "expires today"
        } else if calendar.isDateInTomorrow(date) {
            return "expires tomorrow"
        } else if date < now {
            return "expired"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            return "expires in \(days) days"
        }
    }

    /// Creates a localized expiration description
    @MainActor
    public static func expiration(date: Date, using t: EnhancedTranslationService) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return t.t("accessibility.expires_today")
        } else if calendar.isDateInTomorrow(date) {
            return t.t("accessibility.expires_tomorrow")
        } else if date < now {
            return t.t("accessibility.expired")
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            return t.t("accessibility.expires_in_days", args: ["days": String(days)])
        }
    }

    // MARK: - Numbers & Quantities

    /// Creates a count description (e.g., "5 items")
    public static func count(_ value: Int, singular: String, plural: String) -> String {
        value == 1 ? "1 \(singular)" : "\(value) \(plural)"
    }

    /// Creates a localized count description using the translation service's plural support
    @MainActor
    public static func count(_ value: Int, key: String, using t: EnhancedTranslationService) -> String {
        t.plural(key, count: value)
    }

    /// Creates a distance description
    public static func distance(meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }

    /// Creates a percentage description
    public static func percentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    // MARK: - Status

    /// Creates a status description
    public static func status(
        isAvailable: Bool,
        isPending: Bool = false,
        isExpired: Bool = false,
    ) -> String {
        if isExpired {
            return "expired"
        }
        if isPending {
            return "pending"
        }
        return isAvailable ? "available" : "unavailable"
    }

    /// Creates a localized status description
    @MainActor
    public static func status(
        isAvailable: Bool,
        isPending: Bool = false,
        isExpired: Bool = false,
        using t: EnhancedTranslationService,
    ) -> String {
        if isExpired {
            return t.t("accessibility.status.expired")
        }
        if isPending {
            return t.t("accessibility.status.pending")
        }
        return isAvailable ? t.t("accessibility.status.available") : t.t("accessibility.status.unavailable")
    }

    // MARK: - Actions

    /// Creates a button action description
    public static func buttonAction(_ action: String, target: String? = nil) -> String {
        if let target {
            return "\(action) \(target)"
        }
        return action
    }
}

// MARK: - Custom Accessibility Actions

/// Container for custom accessibility actions
public enum AccessibilityActions {

    /// Creates a claim action for food items
    public static func claimItem(action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Claim item"), action)
    }

    /// Creates a localized claim action for food items
    @MainActor
    public static func claimItem(
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text(t.t("accessibility.action.claim_item")), action)
    }

    /// Creates a share action
    public static func share(action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Share"), action)
    }

    /// Creates a localized share action
    @MainActor
    public static func share(
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text(t.t("accessibility.action.share")), action)
    }

    /// Creates a save action
    public static func save(action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Save for later"), action)
    }

    /// Creates a localized save action
    @MainActor
    public static func save(
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text(t.t("accessibility.action.save_for_later")), action)
    }

    /// Creates a message action
    public static func message(recipient: String, action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Message \(recipient)"), action)
    }

    /// Creates a localized message action
    @MainActor
    public static func message(
        recipient: String,
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(
            named: Text(t.t("accessibility.action.message", args: ["recipient": recipient])),
            action,
        )
    }

    /// Creates a call action
    public static func call(action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Call"), action)
    }

    /// Creates a localized call action
    @MainActor
    public static func call(
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text(t.t("accessibility.action.call")), action)
    }

    /// Creates a directions action
    public static func getDirections(action: @escaping () -> Void) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text("Get directions"), action)
    }

    /// Creates a localized directions action
    @MainActor
    public static func getDirections(
        using t: EnhancedTranslationService,
        action: @escaping () -> Void,
    ) -> AccessibilityActionKind {
        AccessibilityActionKind(named: Text(t.t("accessibility.action.get_directions")), action)
    }
}

/// Wrapper for custom accessibility action
public struct AccessibilityActionKind {
    public let label: Text
    public let action: () -> Void

    public init(named label: Text, _ action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
}

// MARK: - Accessibility Announcement Queue

/// Queue for managing accessibility announcements
@MainActor
public final class AccessibilityAnnouncementQueue {

    public static let shared = AccessibilityAnnouncementQueue()

    private var pendingAnnouncements: [String] = []
    private var isProcessing = false

    private init() {}

    /// Queues an announcement to be spoken
    public func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        switch priority {
        case .immediate:
            // Interrupt current announcement
            UIAccessibility.post(notification: .announcement, argument: message)
        case .high:
            // Insert at front of queue
            pendingAnnouncements.insert(message, at: 0)
            processQueue()
        case .normal:
            // Add to end of queue
            pendingAnnouncements.append(message)
            processQueue()
        }
    }

    /// Announces a success state
    public func announceSuccess(_ message: String) {
        announce("Success: \(message)", priority: .high)
    }

    /// Announces a localized success state
    public func announceSuccess(_ message: String, using t: EnhancedTranslationService) {
        announce(t.t("accessibility.announcement.success", args: ["message": message]), priority: .high)
    }

    /// Announces an error state
    public func announceError(_ message: String) {
        announce("Error: \(message)", priority: .immediate)
    }

    /// Announces a localized error state
    public func announceError(_ message: String, using t: EnhancedTranslationService) {
        announce(t.t("accessibility.announcement.error", args: ["message": message]), priority: .immediate)
    }

    /// Announces a loading state
    public func announceLoading(_ context: String? = nil) {
        let message = context != nil ? "Loading \(context!)" : "Loading"
        announce(message, priority: .normal)
    }

    /// Announces a localized loading state
    public func announceLoading(_ context: String? = nil, using t: EnhancedTranslationService) {
        let message: String = if let context {
            t.t("accessibility.announcement.loading_context", args: ["context": context])
        } else {
            t.t("accessibility.announcement.loading")
        }
        announce(message, priority: .normal)
    }

    /// Announces completion of loading
    public func announceLoaded(_ context: String? = nil, itemCount: Int? = nil) {
        var message = context != nil ? "\(context!) loaded" : "Loaded"
        if let count = itemCount {
            message += ", \(AccessibilityDescription.count(count, singular: "item", plural: "items"))"
        }
        announce(message, priority: .high)
    }

    /// Announces localized completion of loading
    public func announceLoaded(_ context: String? = nil, itemCount: Int? = nil, using t: EnhancedTranslationService) {
        var message: String = if let context {
            t.t("accessibility.announcement.loaded_context", args: ["context": context])
        } else {
            t.t("accessibility.announcement.loaded")
        }
        if let count = itemCount {
            message += ", " + t.t("accessibility.items_count", args: ["count": String(count)])
        }
        announce(message, priority: .high)
    }

    private func processQueue() {
        guard !isProcessing, !pendingAnnouncements.isEmpty else { return }

        isProcessing = true
        let message = pendingAnnouncements.removeFirst()

        UIAccessibility.post(notification: .announcement, argument: message)

        // Wait before processing next announcement
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.isProcessing = false
            self?.processQueue()
        }
    }

    /// Clears all pending announcements
    public func clearQueue() {
        pendingAnnouncements.removeAll()
    }

    public enum AnnouncementPriority {
        case immediate // Interrupts current speech
        case high // Front of queue
        case normal // End of queue
    }
}

// MARK: - Grouped Accessibility Container

/// A container that groups multiple elements for VoiceOver
public struct AccessibilityGroupBox<Content: View>: View {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let content: () -> Content

    public init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.content = content
    }

    public var body: some View {
        content()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

// MARK: - Accessibility Rotor

/// Helper for creating custom accessibility rotors
public enum AccessibilityRotorHelper {

    /// Creates a rotor for navigating food items
    public static func foodItemsRotor<Items: RandomAccessCollection>(
        items: Items,
        selection: Binding<Items.Element?>,
    ) -> some AccessibilityRotorContent where Items.Element: Identifiable {
        ForEach(items) { item in
            AccessibilityRotorEntry(Text("Food item"), id: item.id) {
                selection.wrappedValue = item
            }
        }
    }

    /// Creates a localized rotor for navigating food items
    @MainActor
    public static func foodItemsRotor<Items: RandomAccessCollection>(
        items: Items,
        selection: Binding<Items.Element?>,
        using t: EnhancedTranslationService,
    ) -> some AccessibilityRotorContent where Items.Element: Identifiable {
        ForEach(items) { item in
            AccessibilityRotorEntry(Text(t.t("accessibility.rotor.food_item")), id: item.id) {
                selection.wrappedValue = item
            }
        }
    }

    /// Creates a rotor for navigating headings
    public static func headingsRotor(
        headings: [String],
        onSelect: @escaping (String) -> Void,
    ) -> some AccessibilityRotorContent {
        ForEach(headings, id: \.self) { heading in
            AccessibilityRotorEntry(Text(heading), id: heading) {
                onSelect(heading)
            }
        }
    }
}

// MARK: - Focus Management

/// Helper for managing accessibility focus
@MainActor
public final class AccessibilityFocusManager {

    public static let shared = AccessibilityFocusManager()

    private init() {}

    /// Moves VoiceOver focus to a specific element
    public func focus(on element: Any?) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }

    /// Notifies of a screen change and optionally focuses an element
    public func screenChanged(focusElement: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: focusElement)
    }

    /// Creates a delay before focusing (useful after animations)
    public func delayedFocus(on element: Any?, delay: TimeInterval = 0.3) {
        Task {
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
}

// MARK: - View Extensions

extension View {

    /// Adds a comprehensive accessibility label built from components
    public func accessibilityLabel(
        @AccessibilityLabelBuilder builder: () -> String,
    ) -> some View {
        self.accessibilityLabel(builder())
    }

    /// Adds a single custom accessibility action
    public func accessibilityAction(_ action: AccessibilityActionKind) -> some View {
        self.accessibilityAction(named: action.label, action.action)
    }

    /// Adds two custom accessibility actions
    public func accessibilityActions(
        _ action1: AccessibilityActionKind,
        _ action2: AccessibilityActionKind,
    ) -> some View {
        self
            .accessibilityAction(named: action1.label, action1.action)
            .accessibilityAction(named: action2.label, action2.action)
    }

    /// Adds three custom accessibility actions
    public func accessibilityActions(
        _ action1: AccessibilityActionKind,
        _ action2: AccessibilityActionKind,
        _ action3: AccessibilityActionKind,
    ) -> some View {
        self
            .accessibilityAction(named: action1.label, action1.action)
            .accessibilityAction(named: action2.label, action2.action)
            .accessibilityAction(named: action3.label, action3.action)
    }

    /// Adds four custom accessibility actions
    public func accessibilityActions(
        _ action1: AccessibilityActionKind,
        _ action2: AccessibilityActionKind,
        _ action3: AccessibilityActionKind,
        _ action4: AccessibilityActionKind,
    ) -> some View {
        self
            .accessibilityAction(named: action1.label, action1.action)
            .accessibilityAction(named: action2.label, action2.action)
            .accessibilityAction(named: action3.label, action3.action)
            .accessibilityAction(named: action4.label, action4.action)
    }

    /// Makes the view announce its value changes
    public func accessibilityAnnounceChanges<Value: Equatable>(
        of value: Value,
        message: @escaping (Value) -> String,
    ) -> some View {
        self.onChange(of: value) { _, newValue in
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityAnnouncementQueue.shared.announce(message(newValue))
            }
        }
    }

    /// Adds accessibility traits for a card-style element
    public func accessibilityCard(
        label: String,
        hint: String? = nil,
        isButton: Bool = true,
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isButton ? [.isButton] : [])
    }

    /// Adds accessibility for a loading state
    public func accessibilityLoading(
        isLoading: Bool,
        loadingLabel: String = "Loading",
        loadedLabel: String,
    ) -> some View {
        self
            .accessibilityLabel(isLoading ? loadingLabel : loadedLabel)
            .accessibilityValue(isLoading ? "Loading in progress" : "Loaded")
    }

    /// Adds localized accessibility for a loading state
    @MainActor
    public func accessibilityLoading(
        isLoading: Bool,
        loadedLabel: String,
        using t: EnhancedTranslationService,
    ) -> some View {
        self
            .accessibilityLabel(isLoading ? t.t("accessibility.loading") : loadedLabel)
            .accessibilityValue(isLoading ? t.t("accessibility.loading_in_progress") : t.t("accessibility.loaded"))
    }

    /// Adds fully localized accessibility for a loading state with custom loading label key
    @MainActor
    public func accessibilityLoading(
        isLoading: Bool,
        loadingLabelKey: String,
        loadedLabelKey: String,
        using t: EnhancedTranslationService,
    ) -> some View {
        self
            .accessibilityLabel(isLoading ? t.t(loadingLabelKey) : t.t(loadedLabelKey))
            .accessibilityValue(isLoading ? t.t("accessibility.loading_in_progress") : t.t("accessibility.loaded"))
    }

    /// Groups children with a combined label
    public func accessibilityGroup(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Preview

#Preview("VoiceOver Helpers Demo") {
    struct VoiceOverDemo: View {
        @Environment(\.translationService) private var t

        var body: some View {
            List {
                Section("Food Item Labels") {
                    Text(AccessibilityDescription.foodItem(
                        name: "Fresh Vegetables",
                        category: "Produce",
                        distance: "0.5 miles",
                        expiresIn: "2 days",
                        using: t,
                    ))

                    Text(AccessibilityDescription.foodItemHint(using: t))
                        .foregroundStyle(.secondary)
                }

                Section("User Profiles") {
                    Text(AccessibilityDescription.userProfile(
                        name: "John Smith",
                        itemsShared: 42,
                        rating: 4.8,
                        isVerified: true,
                    ))
                }

                Section("Dates & Times") {
                    Text(AccessibilityDescription.relativeTime(from: Date().addingTimeInterval(-3600)))
                    Text(AccessibilityDescription.expiration(date: Date().addingTimeInterval(86400 * 2)))
                }

                Section("Counts") {
                    Text(AccessibilityDescription.count(1, singular: "item", plural: "items"))
                    Text(AccessibilityDescription.count(5, singular: "item", plural: "items"))
                }
            }
            .navigationTitle("VoiceOver Demo")
        }
    }

    return NavigationStack {
        VoiceOverDemo()
    }
}

#endif
