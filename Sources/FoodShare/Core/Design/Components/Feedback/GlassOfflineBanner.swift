//
//  GlassOfflineBanner.swift
//  Foodshare
//
//  Enhanced Liquid Glass offline status banner v26
//  Features: Animated pulse, breathing effects, glass styling
//


#if !SKIP
import SwiftUI

// MARK: - Enhanced Glass Offline Banner

/// Premium liquid glass banner that displays offline status with animations
struct GlassOfflineBanner: View {
    @Environment(\.translationService) private var t
    let isOffline: Bool
    let lastSyncedAt: Date?
    let onRetry: (() -> Void)?

    @State private var isPulsing = false
    @State private var breathingScale: CGFloat = 1.0

    init(
        isOffline: Bool,
        lastSyncedAt: Date? = nil,
        onRetry: (() -> Void)? = nil,
    ) {
        self.isOffline = isOffline
        self.lastSyncedAt = lastSyncedAt
        self.onRetry = onRetry
    }

    private var lastSyncText: String? {
        guard let date = lastSyncedAt else { return nil }
        #if !SKIP
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return t.t("status.last_synced", args: ["time": formatter.localizedString(for: date, relativeTo: Date())])
        #else
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let timeStr = minutes < 60 ? "\(minutes)m ago" : "\(minutes / 60)h ago"
        return t.t("status.last_synced", args: ["time": timeStr])
        #endif
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Animated offline icon with glass ring
            animatedIcon

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(t.t("status.offline"))
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.DesignSystem.text)

                if let syncText = lastSyncText {
                    Text(syncText)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(Color.DesignSystem.textSecondary)
                }
            }

            Spacer(minLength: 0)

            // Glass retry button
            if let onRetry {
                glassRetryButton(action: onRetry)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(glassOverlay)
        .shadow(color: Color.DesignSystem.warning.opacity(0.2), radius: 12, y: 6)
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animated Icon

    private var animatedIcon: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(Color.DesignSystem.warning.opacity(0.1))
                .frame(width: 40.0, height: 40)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)

            // Inner glass circle
            Circle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .frame(width: 36.0, height: 36)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.warning.opacity(0.5),
                                    Color.DesignSystem.brandOrange.opacity(0.3),
                                    Color.DesignSystem.warning.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 2,
                        ),
                )
                .scaleEffect(breathingScale)

            // WiFi slash icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.brandOrange, Color.DesignSystem.warning],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .scaleEffect(breathingScale)
        }
    }

    // MARK: - Glass Retry Button

    private func glassRetryButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text(t.t("common.retry"))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color.DesignSystem.brandGreen)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandGreen.opacity(0.4),
                                        Color.DesignSystem.brandGreen.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    ),
            )
            .shadow(color: Color.DesignSystem.brandGreen.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(GlassRetryButtonStyle())
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            // Base material
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            // Warning tinted gradient
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.warning.opacity(0.08),
                            Color.DesignSystem.brandOrange.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            // Top light reflection
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private var glassOverlay: some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.DesignSystem.warning.opacity(0.4),
                        Color.DesignSystem.glassBorder,
                        Color.DesignSystem.warning.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 1,
            )
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            isPulsing = true
        }

        // Breathing animation
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breathingScale = 1.05
        }
    }
}

// MARK: - Glass Retry Button Style

struct GlassRetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(Animation.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Offline Indicator Dot

/// Animated glass dot indicator for offline status
struct OfflineIndicatorDot: View {
    let isOffline: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulse (only when offline)
            if isOffline {
                Circle()
                    .fill(Color.DesignSystem.warning.opacity(0.3))
                    .frame(width: 16.0, height: 16)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
            }

            // Main indicator
            Circle()
                .fill(
                    LinearGradient(
                        colors: isOffline
                            ? [Color.DesignSystem.brandOrange, Color.DesignSystem.warning]
                            : [Color.DesignSystem.brandGreen, Color.DesignSystem.success],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 10.0, height: 10)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom,
                            ),
                            lineWidth: 1,
                        ),
                )
                .shadow(
                    color: isOffline
                        ? Color.DesignSystem.warning.opacity(0.5)
                        : Color.DesignSystem.brandGreen.opacity(0.5),
                    radius: 4,
                    y: 1,
                )
        }
        .onAppear {
            if isOffline {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isOffline) { _, newValue in
            if newValue {
                isPulsing = false
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - Animated Offline Banner

/// Wrapper that handles show/hide animation for offline banner
struct AnimatedOfflineBanner: View {
    @Binding var isOffline: Bool
    let lastSyncedAt: Date?
    let onRetry: (() -> Void)?

    init(
        isOffline: Binding<Bool>,
        lastSyncedAt: Date? = nil,
        onRetry: (() -> Void)? = nil,
    ) {
        _isOffline = isOffline
        self.lastSyncedAt = lastSyncedAt
        self.onRetry = onRetry
    }

    var body: some View {
        Group {
            if isOffline {
                GlassOfflineBanner(
                    isOffline: isOffline,
                    lastSyncedAt: lastSyncedAt,
                    onRetry: onRetry,
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95)),
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOffline)
    }
}

// MARK: - Enhanced Glass Cache Status Banner

/// Premium liquid glass banner showing cache status with data freshness indicator
struct GlassCacheStatusBanner: View {
    enum CacheStatus {
        case fresh
        case stale(lastSync: Date)
        case offline(lastSync: Date?)

        var icon: String {
            switch self {
            case .fresh: "checkmark.icloud.fill"
            case .stale: "clock.arrow.circlepath"
            case .offline: "icloud.slash.fill"
            }
        }

        var color: Color {
            switch self {
            case .fresh: Color.DesignSystem.brandGreen
            case .stale: Color.DesignSystem.warning
            case .offline: Color.DesignSystem.error
            }
        }

        var secondaryColor: Color {
            switch self {
            case .fresh: Color.DesignSystem.success
            case .stale: Color.DesignSystem.warning
            case .offline: Color.DesignSystem.accentPink
            }
        }

        var title: String {
            switch self {
            case .fresh: "Up to date"
            case .stale: "Viewing cached data"
            case .offline: "Offline mode"
            }
        }
    }

    let status: CacheStatus
    let onRefresh: (() -> Void)?

    @State private var isRefreshing = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Status icon with glass background
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.DesignSystem.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.DesignSystem.text)

                if case let .stale(date) = status {
                    Text(formatRelativeDate(date))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(Color.DesignSystem.textSecondary)
                } else if case let .offline(date) = status, let date {
                    Text("Last synced: \(formatRelativeDate(date))")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(Color.DesignSystem.textSecondary)
                }
            }

            Spacer(minLength: 0)

            // Refresh button (not shown for fresh status)
            if let onRefresh, case .fresh = status {
                // No refresh needed for fresh data
            } else if let onRefresh {
                glassRefreshButton(action: onRefresh)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [
                            status.color.opacity(0.3),
                            Color.DesignSystem.glassBorder,
                            status.color.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .shadow(color: status.color.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .frame(width: 28.0, height: 28)
                .overlay(
                    Circle()
                        .stroke(status.color.opacity(0.3), lineWidth: 1),
                )

            Image(systemName: status.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [status.color, status.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
    }

    // MARK: - Glass Refresh Button

    private func glassRefreshButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.light()
            withAnimation(.linear(duration: 0.8)) {
                rotationAngle += 360
            }
            action()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(status.color)
                .rotationEffect(.degrees(rotationAngle))
                .frame(width: 28.0, height: 28)
                .background(
                    Circle()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            Circle()
                                .stroke(status.color.opacity(0.2), lineWidth: 1),
                        ),
                )
        }
        .buttonStyle(GlassIconButtonStyle())
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif

            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            status.color.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        #if !SKIP
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
        #else
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        return minutes < 60 ? "\(minutes)m ago" : "\(minutes / 60)h ago"
        #endif
    }
}

// MARK: - Glass Icon Button Style

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(Animation.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extension

extension View {
    /// Attach an offline banner to the top of a view
    func offlineBanner(
        isOffline: Binding<Bool>,
        lastSyncedAt: Date? = nil,
        onRetry: (() -> Void)? = nil,
    ) -> some View {
        VStack(spacing: Spacing.sm) {
            AnimatedOfflineBanner(
                isOffline: isOffline,
                lastSyncedAt: lastSyncedAt,
                onRetry: onRetry,
            )
            self
        }
    }

    /// Add a subtle offline indicator dot to a view
    func offlineIndicator(isOffline: Bool) -> some View {
        overlay(alignment: .topTrailing) {
            if isOffline {
                OfflineIndicatorDot(isOffline: true)
                    .padding(Spacing.xs)
            }
        }
    }

    /// Add a syncing indicator overlay when sync is in progress
    func syncingIndicator(isSyncing: Bool) -> some View {
        overlay(alignment: .top) {
            if isSyncing {
                GlassSyncingBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSyncing)
    }
}

// MARK: - Glass Syncing Banner

/// Compact banner showing sync in progress with animated indicator
struct GlassSyncingBanner: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Animated sync icon
            ZStack {
                Circle()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 28.0, height: 28)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandGreen.opacity(0.5),
                                        Color.DesignSystem.brandBlue.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    )

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            Text("Syncing...")
                .font(.DesignSystem.caption)
                .fontWeight(.medium)
                .foregroundColor(.DesignSystem.text)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.3),
                                    Color.DesignSystem.glassBorder,
                                    Color.DesignSystem.brandBlue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        ),
                ),
        )
        .shadow(color: Color.DesignSystem.brandGreen.opacity(0.15), radius: 8, y: 4)
        .padding(.top, Spacing.sm)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Offline Banner Variants") {
    VStack(spacing: Spacing.md) {
        GlassOfflineBanner(
            isOffline: true,
            lastSyncedAt: Date().addingTimeInterval(-300),
            onRetry: {},
        )

        GlassOfflineBanner(
            isOffline: true,
            lastSyncedAt: nil,
            onRetry: nil,
        )

        GlassCacheStatusBanner(status: .fresh, onRefresh: nil)

        GlassCacheStatusBanner(
            status: .stale(lastSync: Date().addingTimeInterval(-3600)),
            onRefresh: {},
        )

        GlassCacheStatusBanner(
            status: .offline(lastSync: Date().addingTimeInterval(-86400)),
            onRefresh: {},
        )

        HStack {
            Text("Online")
            OfflineIndicatorDot(isOffline: false)
            Spacer()
            Text("Offline")
            OfflineIndicatorDot(isOffline: true)
        }
        .foregroundColor(.white)

        GlassSyncingBanner()
    }
    .padding()
    .background(Color.black)
}

#endif
