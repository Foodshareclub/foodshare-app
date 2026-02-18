
#if !SKIP
import SwiftUI

// MARK: - Sync Conflict

/// Represents a conflict between local and server data
public struct SyncConflict: Identifiable, Sendable {
    public let id: UUID
    public let entityType: EntityType
    public let entityId: String
    public let entityName: String
    public let localVersion: ConflictVersion
    public let serverVersion: ConflictVersion
    public let conflictedFields: [ConflictedField]
    public let createdAt: Date

    public enum EntityType: String, Sendable {
        case listing = "Listing"
        case profile = "Profile"
        case message = "Message"
        case review = "Review"
        case post = "Post"

        public var iconName: String {
            switch self {
            case .listing: "leaf.fill"
            case .profile: "person.fill"
            case .message: "message.fill"
            case .review: "star.fill"
            case .post: "text.bubble.fill"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        entityType: EntityType,
        entityId: String,
        entityName: String,
        localVersion: ConflictVersion,
        serverVersion: ConflictVersion,
        conflictedFields: [ConflictedField],
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.entityName = entityName
        self.localVersion = localVersion
        self.serverVersion = serverVersion
        self.conflictedFields = conflictedFields
        self.createdAt = Date()
    }
}

// MARK: - Conflict Version

public struct ConflictVersion: Sendable {
    public let timestamp: Date
    public let source: String
    public let data: [String: String]

    public init(timestamp: Date, source: String, data: [String: String]) {
        self.timestamp = timestamp
        self.source = source
        self.data = data
    }

    public var formattedTimestamp: String {
        #if !SKIP
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
        #else
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
        #endif
    }
}

// MARK: - Conflicted Field

public struct ConflictedField: Identifiable, Sendable {
    public let id: String
    public let fieldName: String
    public let localValue: String
    public let serverValue: String

    public init(fieldName: String, localValue: String, serverValue: String) {
        self.id = fieldName
        self.fieldName = fieldName
        self.localValue = localValue
        self.serverValue = serverValue
    }

    public var hasSignificantDifference: Bool {
        localValue.lowercased() != serverValue.lowercased()
    }
}

// MARK: - Resolution Strategy

public enum ResolutionStrategy: Sendable {
    case keepLocal
    case useServer
    case merge([String: String]) // Field name to chosen value
}

// MARK: - Conflict Resolution Sheet

/// Glass-styled sheet for resolving sync conflicts
public struct ConflictResolutionSheet: View {

    // MARK: - Properties

    let conflict: SyncConflict
    let onResolve: (ResolutionStrategy) -> Void
    let onDismiss: () -> Void

    @State private var selectedStrategy: ResolutionStrategy?
    @State private var mergedValues: [String: String] = [:]
    @State private var expandedField: String?
    @State private var showConfirmation = false

    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    // MARK: - Initialization

    public init(
        conflict: SyncConflict,
        onResolve: @escaping (ResolutionStrategy) -> Void,
        onDismiss: @escaping () -> Void,
    ) {
        self.conflict = conflict
        self.onResolve = onResolve
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    conflictHeader

                    // Version comparison
                    versionComparison

                    // Field differences
                    fieldDifferences

                    // Quick resolution buttons
                    quickResolutionButtons

                    Spacer(minLength: Spacing.xl)
                }
                .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("sync.resolve_conflict"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) {
                        onDismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            t.t("sync.confirm_resolution"),
            isPresented: $showConfirmation,
            presenting: selectedStrategy,
        ) { strategy in
            Button(t.t("common.confirm"), role: .destructive) {
                onResolve(strategy)
            }
            Button(t.t("common.cancel"), role: .cancel) {
                selectedStrategy = nil
            }
        } message: { strategy in
            Text(confirmationMessage(for: strategy))
        }
    }

    // MARK: - Subviews

    private var conflictHeader: some View {
        VStack(spacing: Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.warning.opacity(0.2))
                    .frame(width: 60.0, height: 60)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.DesignSystem.warning)
            }

            // Title
            Text(t.t("sync.conflict_detected"))
                .font(.DesignSystem.headlineMedium)
                .fontWeight(.semibold)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            // Description
            HStack(spacing: Spacing.xs) {
                Image(systemName: conflict.entityType.iconName)
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Text(conflict.entityName)
                    .fontWeight(.medium)

                Text(t.t("sync.has_conflicts"))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .font(.DesignSystem.bodyMedium)
        }
        .padding(.vertical, Spacing.md)
    }

    private var versionComparison: some View {
        HStack(spacing: Spacing.md) {
            // Local version
            versionCard(
                title: t.t("sync.your_changes"),
                version: conflict.localVersion,
                icon: "iphone",
                color: .DesignSystem.brandGreen,
            )

            // VS divider
            VStack {
                Text(t.t("sync.versus"))
                    .font(.DesignSystem.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .frame(width: 30.0)

            // Server version
            versionCard(
                title: t.t("sync.server_version"),
                version: conflict.serverVersion,
                icon: "cloud.fill",
                color: .DesignSystem.info,
            )
        }
    }

    private func versionCard(
        title: String,
        version: ConflictVersion,
        icon: String,
        color: Color,
    ) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.DesignSystem.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.DesignSystem.textSecondary)

            Text(version.formattedTimestamp)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            Text(version.source)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(color.opacity(0.1)),
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(color.opacity(0.3), lineWidth: 1),
        )
    }

    private var fieldDifferences: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(t.t("sync.conflicting_fields"))
                .font(.DesignSystem.bodyLarge)
                .fontWeight(.semibold)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            ForEach(conflict.conflictedFields) { field in
                fieldComparisonRow(field)
            }
        }
        .padding(.top, Spacing.md)
    }

    private func fieldComparisonRow(_ field: ConflictedField) -> some View {
        VStack(spacing: Spacing.xs) {
            // Field header
            Button {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    expandedField = expandedField == field.id ? nil : field.id
                }
            } label: {
                HStack {
                    Text(field.fieldName.capitalized)
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    Spacer()

                    Image(systemName: expandedField == field.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground),
                )
            }

            // Expanded comparison
            if expandedField == field.id {
                VStack(spacing: Spacing.xs) {
                    // Local value
                    valueRow(
                        label: t.t("sync.your_version"),
                        value: field.localValue,
                        color: .DesignSystem.brandGreen,
                        isSelected: mergedValues[field.id] == field.localValue,
                    ) {
                        mergedValues[field.id] = field.localValue
                    }

                    // Server value
                    valueRow(
                        label: t.t("sync.server_version_label"),
                        value: field.serverValue,
                        color: .DesignSystem.info,
                        isSelected: mergedValues[field.id] == field.serverValue,
                    ) {
                        mergedValues[field.id] = field.serverValue
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func valueRow(
        label: String,
        value: String,
        color: Color,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
    ) -> some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(color)

                    Text(value)
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(isSelected ? color.opacity(0.15) : Color.clear),
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1),
            )
        }
    }

    private var quickResolutionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Text(t.t("sync.quick_resolution"))
                .font(.DesignSystem.bodyLarge)
                .fontWeight(.semibold)
                .foregroundStyle(Color.DesignSystem.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.sm) {
                // Keep Local
                GlassButton(t.t("sync.keep_mine"), icon: "iphone", style: .secondary) {
                    selectedStrategy = .keepLocal
                    showConfirmation = true
                }

                // Use Server
                GlassButton(t.t("sync.use_server"), icon: "cloud.fill", style: .secondary) {
                    selectedStrategy = .useServer
                    showConfirmation = true
                }
            }

            // Merge (if fields selected)
            if !mergedValues.isEmpty {
                GlassButton(t.t("sync.apply_merged"), icon: "arrow.triangle.merge", style: .primary) {
                    selectedStrategy = .merge(mergedValues)
                    showConfirmation = true
                }
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Helpers

    private func confirmationMessage(for strategy: ResolutionStrategy) -> String {
        switch strategy {
        case .keepLocal:
            t.t("sync.confirm_keep_local")
        case .useServer:
            t.t("sync.confirm_use_server")
        case .merge:
            t.t("sync.confirm_merge")
        }
    }
}

// MARK: - Conflict Queue Sheet

/// Sheet showing multiple pending conflicts
public struct ConflictQueueSheet: View {
    @Environment(\.translationService) private var t

    let conflicts: [SyncConflict]
    let onResolve: (SyncConflict, ResolutionStrategy) -> Void
    let onResolveAll: (ResolutionStrategy) -> Void
    let onDismiss: () -> Void

    @State private var selectedConflict: SyncConflict?

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(conflicts) { conflict in
                        conflictRow(conflict)
                    }
                } header: {
                    Text(t.t("sync.conflicts_count", args: ["count": String(conflicts.count)]))
                }

                Section {
                    Button {
                        onResolveAll(.useServer)
                    } label: {
                        Label(t.t("sync.accept_server"), systemImage: "cloud.fill")
                    }

                    Button {
                        onResolveAll(.keepLocal)
                    } label: {
                        Label(t.t("sync.keep_local"), systemImage: "iphone")
                    }
                } header: {
                    Text(t.t("sync.quick_actions"))
                }
            }
            .navigationTitle(t.t("sync.conflicts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.later")) {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedConflict) { conflict in
            ConflictResolutionSheet(
                conflict: conflict,
                onResolve: { strategy in
                    onResolve(conflict, strategy)
                    selectedConflict = nil
                },
                onDismiss: {
                    selectedConflict = nil
                },
            )
        }
    }

    private func conflictRow(_ conflict: SyncConflict) -> some View {
        Button {
            selectedConflict = conflict
        } label: {
            HStack {
                Image(systemName: conflict.entityType.iconName)
                    .foregroundStyle(Color.DesignSystem.warning)

                VStack(alignment: .leading) {
                    Text(conflict.entityName)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    Text(t.t("sync.conflicting_fields_count", args: ["count": String(conflict.conflictedFields.count)]))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let conflict = SyncConflict(
        entityType: .listing,
        entityId: "123",
        entityName: "Fresh Vegetables",
        localVersion: ConflictVersion(
            timestamp: Date().addingTimeInterval(-3600),
            source: "iPhone",
            data: ["title": "Fresh Vegetables", "quantity": "5"],
        ),
        serverVersion: ConflictVersion(
            timestamp: Date().addingTimeInterval(-1800),
            source: "Web",
            data: ["title": "Fresh Organic Vegetables", "quantity": "3"],
        ),
        conflictedFields: [
            ConflictedField(
                fieldName: "title",
                localValue: "Fresh Vegetables",
                serverValue: "Fresh Organic Vegetables",
            ),
            ConflictedField(fieldName: "quantity", localValue: "5", serverValue: "3")
        ],
    )

    ConflictResolutionSheet(
        conflict: conflict,
        onResolve: { _ in },
        onDismiss: {},
    )
}

#endif
