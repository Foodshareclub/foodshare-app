import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    import Inject
#endif

// MARK: - Admin Moderation View

struct AdminModerationView: View {
    
    @Environment(\.translationService) private var t
    @Bindable var viewModel: AdminViewModel
    @State private var selectedItem: ModerationQueueItem?
    @State private var showResolutionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(ModerationStatus.allCases, id: \.self) { status in
                        AdminFilterChip(
                            title: status.localizedDisplayName(using: t),
                            isSelected: viewModel.moderationFilters.status == status,
                            count: status == .pending ? viewModel.pendingModerationCount : nil,
                        ) {
                            viewModel.moderationFilters.status = status
                            Task { await viewModel.loadModerationQueue() }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Spacing.sm)
            .background(Color.DesignSystem.glassSurface)

            // Queue list
            if viewModel.isLoadingModeration, viewModel.moderationQueue.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.moderationQueue.isEmpty {
                Spacer()
                ContentUnavailableView(
                    t.t("admin.no_items"),
                    systemImage: "checkmark.shield",
                    description: Text(t.t("admin.moderation_queue_empty"))
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.moderationQueue) { item in
                        ModerationQueueRow(item: item) {
                            selectedItem = item
                            showResolutionSheet = true
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            await viewModel.loadModerationQueue()
        }
        .sheet(isPresented: $showResolutionSheet) {
            if let item = selectedItem {
                ModerationResolutionSheet(item: item) { resolution, notes in
                    Task {
                        await viewModel.resolveModerationItem(item, resolution: resolution, notes: notes)
                    }
                }
            }
        }
    }
}

// MARK: - Admin Filter Chip (local to AdminModerationView)

private struct AdminFilterChip: View {
    let title: String
    let isSelected: Bool
    var count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.DesignSystem.error))
                }
            }
            .font(.DesignSystem.bodySmall)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? .white : Color.DesignSystem.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.DesignSystem.brandBlue : Color.DesignSystem.glassSurface),
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Moderation Queue Row

struct ModerationQueueRow: View {
    @Environment(\.translationService) private var t
    let item: ModerationQueueItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack {
                    // Priority indicator
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)

                    Text(QueueTypeHelper.localizedName(for: item.queueType, using: t))
                        .font(.DesignSystem.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    Spacer()

                    Text(item.createdAt, style: .relative)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                // Content type
                HStack(spacing: Spacing.sm) {
                    Image(systemName: contentTypeIcon)
                        .foregroundStyle(Color.DesignSystem.brandBlue)

                    Text(ModerationContentType.localizedName(for: item.contentType, using: t))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)

                    if item.isHighPriority {
                        Text(t.t("admin.high_priority"))
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.DesignSystem.error))
                    }
                }

                // Reason
                if let reason = item.flagReason {
                    Text(reason)
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                // Reporter info
                if let reporter = item.reporter {
                    HStack(spacing: Spacing.xs) {
                        Text(t.t("admin.reported_by"))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                        Text(reporter.displayName)
                    }
                    .font(.DesignSystem.caption)
                }

                // Status badge
                HStack {
                    Text(ModerationStatusHelper.localizedName(for: item.status, using: t))
                        .font(.DesignSystem.caption)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(statusColor.opacity(0.2))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.glassSurface.opacity(item.isHighPriority ? 1.5 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        item.isHighPriority ? Color.DesignSystem.error.opacity(0.3) : Color.DesignSystem.glassBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color {
        switch item.priority {
        case 10...: Color.DesignSystem.error
        case 5 ..< 10: Color.DesignSystem.warning
        case 3 ..< 5: Color.DesignSystem.warning.opacity(0.7)
        default: Color.DesignSystem.textSecondary
        }
    }

    private var statusColor: Color {
        switch item.status {
        case "pending": Color.DesignSystem.warning
        case "in_review": Color.DesignSystem.brandBlue
        case "resolved": Color.DesignSystem.success
        case "escalated": Color.DesignSystem.error
        case "dismissed": Color.DesignSystem.textSecondary
        default: Color.DesignSystem.textSecondary
        }
    }

    private var contentTypeIcon: String {
        switch item.contentType {
        case "post": "doc.text"
        case "comment": "bubble.left"
        case "message": "envelope"
        case "profile": "person"
        default: "questionmark.circle"
        }
    }
}

// MARK: - Moderation Resolution Sheet

struct ModerationResolutionSheet: View {
    @Environment(\.translationService) private var t
    let item: ModerationQueueItem
    let onResolve: (ModerationResolution, String?) -> Void

    @State private var selectedResolution: ModerationResolution = .noAction
    @State private var notes = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(t.t("admin.content_details")) {
                    LabeledContent(t.t("admin.type_label"), value: ModerationContentType.localizedName(for: item.contentType, using: t))
                    LabeledContent(
                        t.t("admin.queue_type"),
                        value: QueueTypeHelper.localizedName(for: item.queueType, using: t)
                    )
                    LabeledContent(t.t("admin.priority"), value: "\(item.priority)")

                    if let reason = item.flagReason {
                        LabeledContent(t.t("admin.reason"), value: reason)
                    }

                    if let score = item.flagScore {
                        LabeledContent(t.t("admin.flag_score"), value: String(format: "%.1f", score))
                    }
                }

                Section(t.t("admin.resolution")) {
                    Picker(t.t("admin.action"), selection: $selectedResolution) {
                        ForEach(ModerationResolution.allCases, id: \.self) { resolution in
                            Text(resolution.localizedDisplayName(using: t)).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(t.t("admin.notes")) {
                    TextField(t.t("admin.notes_placeholder"), text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section {
                    Button {
                        onResolve(selectedResolution, notes.isEmpty ? nil : notes)
                        dismiss()
                    } label: {
                        Text(t.t("admin.submit_resolution"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(t.t("admin.resolve_item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Admin Audit Log View

struct AdminAuditLogView: View {
    
    @Environment(\.translationService) private var t
    @Bindable var viewModel: AdminViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingAuditLogs, viewModel.auditLogs.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.auditLogs.isEmpty {
                ContentUnavailableView(
                    t.t("admin.no_audit_logs"),
                    systemImage: "list.clipboard",
                    description: Text(t.t("admin.audit_logs_empty"))
                )
            } else {
                List {
                    ForEach(viewModel.auditLogs) { log in
                        AuditLogRow(log: log)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            await viewModel.loadAuditLogs()
        }
    }
}

// MARK: - Audit Log Row

struct AuditLogRow: View {
    @Environment(\.translationService) private var t
    let log: AdminAuditLog

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                // Admin avatar
                AsyncImage(url: log.admin?.avatarURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.DesignSystem.glassSurface)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(log.admin?.displayName ?? t.t("admin.unknown_admin"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)

                    Text(log.createdAt, style: .relative)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                Spacer()

                // Success/failure indicator
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(log.success ? Color.DesignSystem.success : Color.DesignSystem.error)
            }

            // Action details
            HStack(spacing: Spacing.sm) {
                Text(AdminActionHelper.localizedName(for: log.action, using: t))
                    .font(.DesignSystem.caption)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.DesignSystem.brandBlue.opacity(0.2))
                    .clipShape(Capsule())

                Text(ResourceTypeHelper.localizedName(for: log.resourceType, using: t))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                if let resourceId = log.resourceId {
                    Text("\(t.t("admin.user_id")): \(resourceId.prefix(8))...")
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            // Error message if failed
            if !log.success, let errorMessage = log.errorMessage {
                Text(errorMessage)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.error)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassSurface)
        )
    }
}
