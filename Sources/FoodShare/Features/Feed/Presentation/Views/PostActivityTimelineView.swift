//
//  PostActivityTimelineView.swift
//  Foodshare
//
//  Displays chronological timeline of post activities
//  ProMotion 120Hz optimized with smooth animations
//


#if !SKIP
import SwiftUI

// MARK: - Post Activity Timeline View

/// Displays a chronological timeline of activities for a post
struct PostActivityTimelineView: View {
    // MARK: - Properties

    let postId: Int
    let showActor: Bool
    let compact: Bool

    // MARK: - State

    @State private var activities: [PostActivityItem] = []
    @State private var isLoading = true
    @State private var error: Error?

    @Environment(\.translationService) private var t

    // MARK: - Initialization

    init(postId: Int, showActor: Bool = true, compact: Bool = false) {
        self.postId = postId
        self.showActor = showActor
        self.compact = compact
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if activities.isEmpty {
                emptyView
            } else {
                timelineContent
            }
        }
        .task {
            await loadActivities()
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        ScrollView {
            LazyVStack(spacing: compact ? 12 : 16) {
                ForEach(activities) { activity in
                    ActivityItemView(
                        activity: activity,
                        showActor: showActor,
                        compact: compact,
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.brandGreen))
            Text(t.t("post_activity.loading"))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.DesignSystem.textTertiary)

            Text(t.t("post_activity.no_activity"))
                .font(.headline)
                .foregroundColor(.DesignSystem.textSecondary)

            Text(t.t("post_activity.no_activity_desc"))
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.DesignSystem.warning)

            Text(t.t("post_activity.load_failed"))
                .font(.headline)
                .foregroundColor(.DesignSystem.textPrimary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            GlassButton(t.t("common.try_again"), icon: "arrow.clockwise", style: .secondary) {
                Task { await loadActivities() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Activities

    private func loadActivities() async {
        isLoading = true
        error = nil

        do {
            activities = try await PostActivityService.shared.getActivities(for: postId)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

// MARK: - Activity Item View

/// Single activity item in the timeline
private struct ActivityItemView: View {
    let activity: PostActivityItem
    let showActor: Bool
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Icon circle
                Circle()
                    .fill(Color(hex: activity.activityType.colorHex).opacity(0.15))
                    .frame(width: 36.0, height: 36)
                    .overlay(
                        Image(systemName: activity.activityType.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: activity.activityType.colorHex)),
                    )

                // Connecting line
                if !compact {
                    Rectangle()
                        .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                        .frame(width: 2.0)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    if showActor, let nickname = activity.actorNickname {
                        Text(nickname)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.textPrimary)
                    }

                    Text(activity.activityType.label.lowercased())
                        .font(.subheadline)
                        .foregroundColor(Color(hex: activity.activityType.colorHex))

                    Spacer()

                    #if !SKIP
                    Text(activity.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.DesignSystem.textTertiary)
                    #else
                    Text({
                        let interval = Date().timeIntervalSince(activity.createdAt)
                        if interval < 60 { return "just now" }
                        if interval < 3600 { return "\(Int(interval / 60))m ago" }
                        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
                        return "\(Int(interval / 86400))d ago"
                    }())
                        .font(.caption)
                        .foregroundColor(Color.DesignSystem.textTertiary)
                    #endif
                }

                // Reason/Notes
                if !compact {
                    if let reason = activity.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }

                    if let notes = activity.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.DesignSystem.textTertiary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, compact ? 8 : 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1),
                    ),
            )
        }
    }
}

// MARK: - Post Activity Stats View

/// Compact stats view for post activity
struct PostActivityStatsView: View {
    let postId: Int

    @State private var stats: PostActivityStats?
    @State private var isLoading = true

    @Environment(\.translationService) private var t

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 60.0)
            } else if let stats {
                statsContent(stats)
            }
        }
        .task {
            await loadStats()
        }
    }

    private func statsContent(_ stats: PostActivityStats) -> some View {
        HStack(spacing: 24) {
            statItem(icon: "eye.fill", value: stats.viewCount, label: t.t("post_activity.views"))
            statItem(icon: "heart.fill", value: stats.likeCount, label: t.t("post_activity.likes"))
            statItem(icon: "square.and.arrow.up.fill", value: stats.shareCount, label: t.t("post_activity.shares"))
            statItem(icon: "message.fill", value: stats.contactCount, label: t.t("post_activity.contacts"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1),
                ),
        )
    }

    private func statItem(icon: String, value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.DesignSystem.brandGreen)

                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.textPrimary)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.DesignSystem.textTertiary)
        }
    }

    private func loadStats() async {
        do {
            stats = try await PostActivityService.shared.getActivityStats(for: postId)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview("Activity Timeline") {
    PostActivityTimelineView(postId: 1)
        .background(Color.black)
}

#Preview("Activity Stats") {
    PostActivityStatsView(postId: 1)
        .padding()
        .background(Color.black)
}

#endif
