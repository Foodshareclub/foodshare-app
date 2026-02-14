import SwiftUI
import FoodShareDesignSystem



// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    
    @Environment(\.translationService) private var t
    @State private var viewModel: AdminViewModel
    @State private var selectedTab: AdminTab = .dashboard
    @State private var hasAppeared = false

    init(viewModel: AdminViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient
                    .ignoresSafeArea()

                if !viewModel.hasAdminAccess {
                    accessDeniedView
                } else {
                    TabView(selection: $selectedTab) {
                        dashboardTab
                            .tag(AdminTab.dashboard)
                            .tabItem {
                                Label(t.t("admin.dashboard"), systemImage: "chart.bar")
                            }

                        usersTab
                            .tag(AdminTab.users)
                            .tabItem {
                                Label(t.t("admin.users"), systemImage: "person.3")
                            }

                        moderationTab
                            .tag(AdminTab.moderation)
                            .tabItem {
                                Label(t.t("admin.moderation"), systemImage: "shield")
                            }

                        auditLogTab
                            .tag(AdminTab.auditLog)
                            .tabItem {
                                Label(t.t("admin.audit_log"), systemImage: "list.clipboard")
                            }
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
            }
            .navigationTitle(t.t("admin.title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
        }
        .task {
            await viewModel.checkAccess()
            if viewModel.hasAdminAccess {
                await viewModel.loadDashboardStats()
                await viewModel.loadRoles()
            }
        }
        .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
            Button(t.t("common.ok")) { viewModel.dismissError() }
        } message: {
            Text(viewModel.error?.localizedDescription ?? t.t("common.error_occurred"))
        }
        .alert(t.t("common.success"), isPresented: $viewModel.showSuccess) {
            Button(t.t("common.ok")) { viewModel.dismissSuccess() }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Dashboard Tab

    private var dashboardTab: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Overview Header with animated ring chart
                overviewHeader

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Spacing.md) {
                    StatCard(
                        title: t.t("admin.stats.total_users"),
                        value: "\(viewModel.stats.totalUsers)",
                        icon: "person.3.fill",
                        color: Color.DesignSystem.brandBlue
                    )

                    StatCard(
                        title: t.t("admin.stats.active_users"),
                        value: "\(viewModel.stats.activeUsers)",
                        icon: "person.fill.checkmark",
                        color: Color.DesignSystem.success
                    )

                    StatCard(
                        title: t.t("admin.stats.total_posts"),
                        value: "\(viewModel.stats.totalPosts)",
                        icon: "doc.text.fill",
                        color: Color.DesignSystem.warning
                    )

                    StatCard(
                        title: t.t("admin.stats.active_posts"),
                        value: "\(viewModel.stats.activePosts)",
                        icon: "doc.fill",
                        color: Color.DesignSystem.brandPurple
                    )

                    StatCard(
                        title: t.t("admin.stats.pending_reports"),
                        value: "\(viewModel.stats.pendingReports)",
                        icon: "exclamationmark.triangle.fill",
                        color: viewModel.stats.pendingReports > 0
                            ? Color.DesignSystem.error
                            : Color.DesignSystem.textSecondary
                    )

                    StatCard(
                        title: t.t("admin.stats.messages"),
                        value: "\(viewModel.stats.totalMessages)",
                        icon: "bubble.left.and.bubble.right.fill",
                        color: Color.DesignSystem.brandCyan
                    )
                }

                // Today's Activity
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.DesignSystem.primary)
                        Text(t.t("admin.todays_activity"))
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)
                    }

                    HStack(spacing: Spacing.md) {
                        AdminActivityCard(
                            title: t.t("admin.new_users"),
                            value: viewModel.stats.newUsersToday,
                            icon: "person.badge.plus"
                        )

                        AdminActivityCard(
                            title: t.t("admin.new_posts"),
                            value: viewModel.stats.newPostsToday,
                            icon: "plus.square"
                        )
                    }
                }
                .padding(Spacing.md)
                .glassEffect(cornerRadius: CornerRadius.large)
                .staggeredAppearance(index: 7, baseDelay: 0.05)

                // Quick Actions
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.DesignSystem.warning)
                        Text(t.t("admin.quick_actions"))
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)
                    }

                    HStack(spacing: Spacing.sm) {
                        QuickActionButton(
                            title: t.t("admin.view_reports"),
                            icon: "flag.fill",
                            color: Color.DesignSystem.error
                        ) {
                            HapticManager.light()
                            selectedTab = .moderation
                        }

                        QuickActionButton(
                            title: t.t("admin.manage_users"),
                            icon: "person.2.fill",
                            color: Color.DesignSystem.brandBlue
                        ) {
                            HapticManager.light()
                            selectedTab = .users
                        }
                    }
                }
                .padding(Spacing.md)
                .glassEffect(cornerRadius: CornerRadius.large)
                .staggeredAppearance(index: 8, baseDelay: 0.05)
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDashboardStats()
        }
    }

    // MARK: - Users Tab

    private var usersTab: some View {
        AdminUsersView(viewModel: viewModel)
    }

    // MARK: - Moderation Tab

    private var moderationTab: some View {
        AdminModerationView(viewModel: viewModel)
    }

    // MARK: - Audit Log Tab

    private var auditLogTab: some View {
        AdminAuditLogView(viewModel: viewModel)
    }

    // MARK: - Overview Header

    private var overviewHeader: some View {
        HStack(spacing: Spacing.lg) {
            // Animated Ring Chart
            AdminRingChart(
                totalUsers: viewModel.stats.totalUsers,
                activeUsers: viewModel.stats.activeUsers,
                totalPosts: viewModel.stats.totalPosts,
                activePosts: viewModel.stats.activePosts,
                healthLabel: t.t("admin.health")
            )
            .frame(width: 120, height: 120)

            // Summary stats
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(t.t("admin.platform_health"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HealthMetric(
                        label: t.t("admin.user_activity"),
                        value: viewModel.stats.totalUsers > 0
                            ? Double(viewModel.stats.activeUsers) / Double(viewModel.stats.totalUsers)
                            : 0,
                        color: .DesignSystem.success
                    )

                    HealthMetric(
                        label: t.t("admin.content_active"),
                        value: viewModel.stats.totalPosts > 0
                            ? Double(viewModel.stats.activePosts) / Double(viewModel.stats.totalPosts)
                            : 0,
                        color: .DesignSystem.brandBlue
                    )

                    HealthMetric(
                        label: t.t("admin.reports_queue"),
                        value: viewModel.stats.pendingReports > 10 ? 0.2 : 1.0 - (Double(viewModel.stats.pendingReports) * 0.08),
                        color: viewModel.stats.pendingReports > 5 ? .DesignSystem.error : .DesignSystem.warning
                    )
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .glassEffect(cornerRadius: CornerRadius.large)
        .staggeredAppearance(index: 0, baseDelay: 0.05)
    }

    // MARK: - Access Denied

    private var accessDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.error.opacity(0.2),
                                Color.DesignSystem.error.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.shield")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.DesignSystem.error.opacity(0.7))
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("admin.access_denied"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("admin.access_denied_message"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()
        }
    }
}

// MARK: - Admin Tab

enum AdminTab: String, CaseIterable {
    case dashboard
    case users
    case moderation
    case auditLog
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Spacer()
            }

            Text(value)
                .font(.DesignSystem.displaySmall)
                .fontWeight(.bold)
                .foregroundColor(.DesignSystem.text)
                .contentTransition(.numericText())

            Text(title)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Admin Activity Card

struct AdminActivityCard: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.brandBlue.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.brandBlue)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(value)")
                    .font(.DesignSystem.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text)
                    .contentTransition(.numericText())

                Text(title)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(Color.glassBorder, lineWidth: 1),
                ),
        )
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.DesignSystem.labelSmall)
                    .foregroundColor(.DesignSystem.text)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .strokeBorder(Color.glassBorder, lineWidth: 1),
                    ),
            )
        }
        .buttonStyle(.plain)
        .pressAnimation()
    }
}

// MARK: - Admin Ring Chart

struct AdminRingChart: View {
    let totalUsers: Int
    let activeUsers: Int
    let totalPosts: Int
    let activePosts: Int
    let healthLabel: String

    @State private var animationProgress: Double = 0

    private var userRatio: Double {
        totalUsers > 0 ? Double(activeUsers) / Double(totalUsers) : 0
    }

    private var postRatio: Double {
        totalPosts > 0 ? Double(activePosts) / Double(totalPosts) : 0
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = min(size.width, size.height) / 2 - 8
            let ringWidth: CGFloat = 12

            // Background rings
            drawRing(context: context, center: center, radius: outerRadius, width: ringWidth, progress: 1.0, color: Color.DesignSystem.success.opacity(0.15))
            drawRing(context: context, center: center, radius: outerRadius - ringWidth - 4, width: ringWidth, progress: 1.0, color: Color.DesignSystem.brandBlue.opacity(0.15))

            // Animated progress rings
            drawRing(context: context, center: center, radius: outerRadius, width: ringWidth, progress: userRatio * animationProgress, color: Color.DesignSystem.success)
            drawRing(context: context, center: center, radius: outerRadius - ringWidth - 4, width: ringWidth, progress: postRatio * animationProgress, color: Color.DesignSystem.brandBlue)

            // Center circle
            let centerCirclePath = Path(ellipseIn: CGRect(
                x: center.x - 30,
                y: center.y - 30,
                width: 60,
                height: 60
            ))
            context.fill(centerCirclePath, with: .color(Color.DesignSystem.glassBackground))

            // Center text
            let healthScore = Int((userRatio + postRatio) / 2 * 100 * animationProgress)
            context.draw(
                Text("\(healthScore)%")
                    .font(.DesignSystem.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text),
                at: CGPoint(x: center.x, y: center.y - 6)
            )
            context.draw(
                Text(healthLabel)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary),
                at: CGPoint(x: center.x, y: center.y + 12)
            )
        }
        .drawingGroup()
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) {
                animationProgress = 1.0
            }
        }
    }

    private func drawRing(context: GraphicsContext, center: CGPoint, radius: CGFloat, width: CGFloat, progress: Double, color: Color) {
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + 360 * progress)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}

// MARK: - Health Metric

struct HealthMetric: View {
    let label: String
    let value: Double
    let color: Color

    @State private var animatedValue: Double = 0

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(width: 90, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geometry.size.width * animatedValue), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(animatedValue * 100))%")
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(color)
                .frame(width: 36, alignment: .trailing)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedValue = newValue
            }
        }
    }
}
