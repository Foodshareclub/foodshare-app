//
//  LeaderboardView.swift
//  Foodshare
//
//  Leaderboard view with Liquid Glass design
//


#if !SKIP
import Supabase
import SwiftUI

#if DEBUG
    import Inject
#endif

struct LeaderboardView: View {
    
    @Environment(\.translationService) private var t
    @State private var leaders: [LeaderboardEntry] = []
    @State private var previousRanks: [UUID: Int] = [:]
    @State private var isLoading = true
    @State private var selectedCategory: LeaderboardCategory = .itemsShared
    @State private var selectedTimePeriod: TimePeriod = .allTime
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showShareSheet = false
    @State private var shareEntry: LeaderboardEntry?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var body: some View {
        ZStack {
            Color.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                // Time period filter
                timePeriodPicker

                // Category picker
                categoryPicker

                // Leaderboard content
                leaderboardContent
            }
        }
        .navigationTitle(t.t("challenges.leaderboard"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadLeaderboard()
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await loadLeaderboard() }
        }
        .onChange(of: selectedTimePeriod) { _, _ in
            Task { await loadLeaderboard() }
        }
        .alert(t.t("common.error.title"), isPresented: $showError) {
            Button(t.t("common.ok")) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $shareEntry) { entry in
            ShareLeaderboardSheet(entry: entry, category: selectedCategory, timePeriod: selectedTimePeriod)
        }
    }

    // MARK: - Time Period Picker

    private var timePeriodPicker: some View {
        HStack(spacing: 0) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTimePeriod = period
                    }
                    HapticManager.light()
                } label: {
                    Text(period.title(using: t))
                        .font(.LiquidGlass.labelMedium)
                        .fontWeight(selectedTimePeriod == period ? .semibold : .regular)
                        .foregroundColor(selectedTimePeriod == period ? .white : .DesignSystem.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            selectedTimePeriod == period
                                ? Color.DesignSystem.brandGreen
                                : Color.clear,
                        )
                }
            }
        }
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
        .padding(Edge.Set.horizontal, Spacing.md)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(Edge.Set.horizontal, Spacing.md)
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    private func categoryButton(_ category: LeaderboardCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = category
            }
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.title(using: t))
                    .font(.DesignSystem.labelMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isSelected ? .white : .DesignSystem.text)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ))
                    : AnyShapeStyle(Color.DesignSystem.glassBackground),
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.DesignSystem.glassBorder, lineWidth: 1),
            )
        }
        .pressAnimation()
    }

    // MARK: - Leaderboard Content

    @ViewBuilder
    private var leaderboardContent: some View {
        if isLoading {
            loadingView
        } else if leaders.isEmpty {
            emptyState
        } else {
            leaderboardList
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text(t.t("challenges.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )

            Text(t.t("challenges.no_leaders"))
                .font(.DesignSystem.headlineMedium)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("challenges.no_leaders_description"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                // Top 3 Podium
                if leaders.count >= 3 {
                    podiumView
                }

                // Rest of the list
                ForEach(Array(leaders.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(entry: entry, rank: index + 4)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Podium View (Top 3)

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            // 2nd Place
            if leaders.count > 1 {
                podiumCard(entry: leaders[1], rank: 2, height: 120)
            }

            // 1st Place
            if !leaders.isEmpty {
                podiumCard(entry: leaders[0], rank: 1, height: 150)
            }

            // 3rd Place
            if leaders.count > 2 {
                podiumCard(entry: leaders[2], rank: 3, height: 100)
            }
        }
        .padding(.vertical, Spacing.lg)
    }

    private func podiumCard(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: Spacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rank == 1
                                ? [.DesignSystem.medalGold, .DesignSystem.accentOrange]
                                : rank == 2
                                    ? [.DesignSystem.medalSilver.opacity(0.8), .DesignSystem.medalSilver]
                                    : [.DesignSystem.accentOrange.opacity(0.6), .DesignSystem.medalBronze.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                    )
                    .frame(width: rank == 1 ? 70 : 56, height: rank == 1 ? 70 : 56)

                AsyncImage(url: entry.avatarURL) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Image(systemName: "person.fill")
                            .font(.system(size: rank == 1 ? 28 : 22))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: rank == 1 ? 64 : 50, height: rank == 1 ? 64 : 50)
                .clipShape(Circle())

                // Medal
                Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                    .font(.system(size: rank == 1 ? 20 : 16))
                    .foregroundColor(rank == 1
                        ? .DesignSystem.medalGold
                        : rank == 2 ? .DesignSystem.medalSilver : .DesignSystem.medalBronze)
                        .offset(y: rank == 1 ? -40 : -32)
            }

            // Name
            Text(localizedName(entry.displayName))
                .font(.DesignSystem.labelSmall)
                .fontWeight(.semibold)
                .foregroundColor(.DesignSystem.text)
                .lineLimit(1)

            // Score
            Text("\(entry.score)")
                .font(.DesignSystem.headlineMedium)
                .fontWeight(.black)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )

            // Rank indicator
            Text("#\(rank)")
                .font(.DesignSystem.captionSmall)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(
                    rank == 1
                        ? Color.DesignSystem.medalGold
                        : rank == 2 ? Color.DesignSystem.medalSilver : Color.DesignSystem.medalBronze,
                )
                .clipShape(Capsule())
        }
        .frame(width: rank == 1 ? 110 : 90, height: height)
        .padding(Spacing.md)
        .glassBackground(cornerRadius: CornerRadius.large)
    }

    // MARK: - Leaderboard Row

    private func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        let rankChange = calculateRankChange(for: entry, currentRank: rank)

        return HStack(spacing: Spacing.md) {
            // Rank with change indicator
            VStack(spacing: 2) {
                Text("#\(rank)")
                    .font(.DesignSystem.labelLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.textSecondary)

                if let change = rankChange {
                    RankChangeIndicator(change: change)
                }
            }
            .frame(width: 44.0)

            // Avatar
            AsyncImage(url: entry.avatarURL) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.DesignSystem.textSecondary),
                        )
                }
            }
            .frame(width: 44.0, height: 44)
            .clipShape(Circle())

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(localizedName(entry.displayName))
                        .font(.DesignSystem.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)

                    if entry.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.DesignSystem.brandBlue)
                    }
                }

                Text(selectedCategory.subtitle(using: t))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            Spacer()

            // Score and share button
            HStack(spacing: Spacing.sm) {
                Text("\(entry.score)")
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.black)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )

                Button {
                    shareEntry = entry
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
    }

    private func calculateRankChange(for entry: LeaderboardEntry, currentRank: Int) -> Int? {
        guard let previousRank = previousRanks[entry.id] else { return nil }
        let change = previousRank - currentRank
        return change != 0 ? change : nil
    }

    // MARK: - Data Loading

    private func loadLeaderboard() async {
        isLoading = true

        do {
            let column = selectedCategory.columnName
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let response = try await client
                .from("profile_stats")
                .select("""
                    profile_id, \(column),
                    profiles(id, nickname, avatar_url, is_verified)
                """)
                .gt(column, value: 0)
                .order(column, ascending: false)
                .limit(50)
                .execute()

            let entries = try decoder.decode([LeaderboardResponse].self, from: response.data)

            leaders = entries.compactMap { entry in
                guard let profile = entry.profiles else { return nil }

                let score: Int = switch selectedCategory {
                case .itemsShared:
                    entry.itemsShared ?? 0
                case .itemsReceived:
                    entry.itemsReceived ?? 0
                case .reviews:
                    entry.ratingCount ?? 0
                case .impact:
                    (entry.itemsShared ?? 0) + (entry.itemsReceived ?? 0)
                }

                guard score > 0 else { return nil }

                return LeaderboardEntry(
                    id: profile.id,
                    displayName: profile.nickname ?? "Anonymous",
                    avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                    score: score,
                    isVerified: profile.isVerified ?? false,
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func localizedName(_ name: String) -> String {
        name == "Anonymous" ? t.t("common.anonymous") : name
    }
}

// MARK: - Supporting Types

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let displayName: String
    let avatarURL: URL?
    let score: Int
    let isVerified: Bool
}

private struct LeaderboardResponse: Decodable {
    let profileId: UUID
    let itemsShared: Int?
    let itemsReceived: Int?
    let ratingCount: Int?
    let sharedPostsCounter: Int?
    let profiles: LeaderboardProfileInfo?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case itemsShared = "items_shared"
        case itemsReceived = "items_received"
        case ratingCount = "rating_count"
        case sharedPostsCounter = "shared_posts_counter"
        case profiles
    }
}

private struct LeaderboardProfileInfo: Decodable {
    let id: UUID
    let nickname: String?
    let avatarUrl: String?
    let isVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case isVerified = "is_verified"
    }
}

// MARK: - Time Period Enum

enum TimePeriod: String, CaseIterable, Sendable {
    case weekly
    case monthly
    case allTime = "all_time"

    @MainActor
    func title(using t: EnhancedTranslationService) -> String {
        switch self {
        case .weekly: t.t("leaderboard.period.this_week")
        case .monthly: t.t("leaderboard.period.this_month")
        case .allTime: t.t("leaderboard.period.all_time")
        }
    }

    var dateFilter: Date? {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: -7, to: Date())
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: Date())
        case .allTime:
            return nil
        }
    }
}

// MARK: - Leaderboard Category Enum

enum LeaderboardCategory: CaseIterable {
    case itemsShared
    case itemsReceived
    case reviews
    case impact

    @MainActor
    func title(using t: EnhancedTranslationService) -> String {
        switch self {
        case .itemsShared: t.t("leaderboard.category.items_shared")
        case .itemsReceived: t.t("leaderboard.category.items_received")
        case .reviews: t.t("leaderboard.category.reviews")
        case .impact: t.t("leaderboard.category.total_impact")
        }
    }

    @MainActor
    func subtitle(using t: EnhancedTranslationService) -> String {
        switch self {
        case .itemsShared: t.t("leaderboard.subtitle.items_shared")
        case .itemsReceived: t.t("leaderboard.subtitle.items_received")
        case .reviews: t.t("leaderboard.subtitle.reviews")
        case .impact: t.t("leaderboard.subtitle.total_impact")
        }
    }

    var icon: String {
        switch self {
        case .itemsShared: "leaf.fill"
        case .itemsReceived: "hand.raised.fill"
        case .reviews: "star.fill"
        case .impact: "sparkles"
        }
    }

    var columnName: String {
        switch self {
        case .itemsShared: "items_shared"
        case .itemsReceived: "items_received"
        case .reviews: "rating_count"
        case .impact: "items_shared"
        }
    }
}

// MARK: - Rank Change Indicator

struct RankChangeIndicator: View {
    let change: Int

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .bold))
            Text("\(abs(change))")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(change > 0 ? .DesignSystem.success : .DesignSystem.error)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            (change > 0 ? Color.DesignSystem.success : Color.DesignSystem.error)
                .opacity(0.15),
        )
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Share Leaderboard Sheet

struct ShareLeaderboardSheet: View {
    let entry: LeaderboardEntry
    let category: LeaderboardCategory
    let timePeriod: TimePeriod
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Share card preview
                    shareCardPreview

                    // Share options
                    VStack(spacing: Spacing.md) {
                        #if !SKIP
                        ShareLink(item: shareText) {
                            Label(t.t("leaderboard.share_achievement"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.DesignSystem.brandGreen)
                                .foregroundColor(.white)
                                .font(.DesignSystem.labelLarge)
                                .fontWeight(.semibold)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        #else
                        Button(action: {}) {
                            Label(t.t("leaderboard.share_achievement"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.DesignSystem.brandGreen)
                                .foregroundColor(.white)
                                .font(.DesignSystem.labelLarge)
                                .fontWeight(.semibold)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        #endif

                        Button {
                            UIPasteboard.general.string = shareText
                            HapticManager.success()
                            dismiss()
                        } label: {
                            Label(t.t("common.copy_to_clipboard"), systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.DesignSystem.glassBackground)
                                .foregroundColor(.DesignSystem.text)
                                .font(.DesignSystem.labelLarge)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer()
                }
                .padding(.top, Spacing.lg)
            }
            .navigationTitle(t.t("challenges.share_achievement"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private var shareCardPreview: some View {
        VStack(spacing: Spacing.md) {
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )

            // Name
            Text(localizedName(entry.displayName))
                .font(.DesignSystem.headlineLarge)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)

            // Score
            HStack(spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .foregroundColor(.DesignSystem.brandGreen)
                Text("\(entry.score) \(category.subtitle(using: t))")
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            // Time period badge
            Text(timePeriod.title(using: t))
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.DesignSystem.brandBlue)
                .clipShape(Capsule())

            // App branding
            HStack(spacing: Spacing.xs) {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundColor(.DesignSystem.brandGreen)
                Text(t.t("app.name"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: CornerRadius.large)
        .padding(.horizontal, Spacing.lg)
    }

    private var shareText: String {
        """
        🏆 \(localizedName(entry.displayName)) \(t.t("leaderboard.share_making_impact"))

        📊 \(entry.score) \(category.subtitle(using: t)) (\(timePeriod.title(using: t)))

        \(t.t("leaderboard.share_join_movement"))
        \(t.t("leaderboard.share_hashtags"))
        """
    }

    private func localizedName(_ name: String) -> String {
        name == "Anonymous" ? t.t("common.anonymous") : name
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeaderboardView(client: AuthenticationService.shared.supabase)
    }
}

#endif
