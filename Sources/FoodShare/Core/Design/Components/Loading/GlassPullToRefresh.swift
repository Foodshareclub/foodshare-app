import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Pull To Refresh

/// Custom Liquid Glass styled pull-to-refresh with elastic physics
/// and animated glass orb indicator
public struct GlassPullToRefresh<Content: View>: View {

    // MARK: - Properties

    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    let threshold: CGFloat
    let maxPull: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var pullProgress: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggered = false
    @State private var orbRotation: Double = 0
    @State private var orbScale: CGFloat = 1.0
    @State private var showSuccess = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    public init(
        isRefreshing: Binding<Bool>,
        threshold: CGFloat = 80,
        maxPull: CGFloat = 150,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self._isRefreshing = isRefreshing
        self.threshold = threshold
        self.maxPull = maxPull
        self.onRefresh = onRefresh
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { _ in
            ScrollView {
                VStack(spacing: 0) {
                    // Pull indicator
                    pullIndicator
                        .frame(height: max(0, pullProgress))
                        .opacity(pullProgress > 0 ? 1 : 0)

                    // Content
                    content()
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin.y,
                        )
                    },
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                handleScrollOffset(offset)
            }
        }
        .onChange(of: isRefreshing) { _, newValue in
            if !newValue, hasTriggered {
                completeRefresh()
            }
        }
    }

    // MARK: - Subviews

    private var pullIndicator: some View {
        VStack {
            Spacer()

            ZStack {
                // Outer rings
                if !reduceMotion {
                    ForEach(0 ..< 3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.DesignSystem.brandGreen.opacity(0.2 - Double(index) * 0.05),
                                lineWidth: 2,
                            )
                            .frame(width: 50 + CGFloat(index) * 15, height: 50 + CGFloat(index) * 15)
                            .scaleEffect(isRefreshing ? 1.1 : 1.0)
                            .opacity(pullProgress / threshold)
                            .animation(
                                .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                value: isRefreshing,
                            )
                    }
                }

                // Glass orb
                glassOrb

                // Success checkmark overlay
                if showSuccess {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.DesignSystem.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Progress text
            if pullProgress > 20 {
                Text(statusText)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.top, Spacing.xs)
                    .transition(.opacity)
            }

            Spacer()
        }
    }

    private var glassOrb: some View {
        ZStack {
            // Glass background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)

            // Gradient overlay
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(progressOpacity * 0.3),
                            Color.DesignSystem.brandGreen.opacity(progressOpacity * 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 44, height: 44)

            // Progress arc
            Circle()
                .trim(from: 0, to: isRefreshing ? 1 : min(pullProgress / threshold, 1))
                .stroke(
                    Color.DesignSystem.brandGreen,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round),
                )
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(isRefreshing ? orbRotation : -90))
                .animation(
                    isRefreshing
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .interpolatingSpring(stiffness: 300, damping: 20),
                    value: isRefreshing,
                )

            // Arrow icon
            if !isRefreshing, !showSuccess {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                    .rotationEffect(.degrees(pullProgress >= threshold ? 180 : 0))
                    .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: pullProgress >= threshold)
            }
        }
        .scaleEffect(orbScale)
        .onChange(of: isRefreshing) { _, newValue in
            if newValue {
                startSpinAnimation()
            }
        }
    }

    // MARK: - Computed Properties

    private var progressOpacity: Double {
        min(1, pullProgress / threshold)
    }

    private var statusText: String {
        if showSuccess {
            "Updated!"
        } else if isRefreshing {
            "Refreshing..."
        } else if pullProgress >= threshold {
            "Release to refresh"
        } else {
            "Pull to refresh"
        }
    }

    // MARK: - Scroll Handling

    private func handleScrollOffset(_ offset: CGFloat) {
        // Only handle positive offsets (pulling down)
        guard offset > 0 else {
            if pullProgress > 0, !isRefreshing {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    pullProgress = 0
                }
            }
            return
        }

        // Apply elastic resistance
        let elasticOffset = elasticPull(offset)
        pullProgress = elasticOffset

        // Check if we should trigger refresh
        if offset >= threshold, !hasTriggered, !isRefreshing {
            triggerRefresh()
        }
    }

    private func elasticPull(_ offset: CGFloat) -> CGFloat {
        if offset <= threshold {
            return offset
        }

        // Elastic overpull: diminishing returns past threshold
        let overpull = offset - threshold
        let elasticOverpull = threshold + (overpull * 0.4)
        return min(elasticOverpull, maxPull)
    }

    // MARK: - Refresh Actions

    private func triggerRefresh() {
        hasTriggered = true
        isRefreshing = true

        // Haptic feedback
        HapticManager.shared.impact(.medium)

        // Bounce animation
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
            orbScale = 1.2
        }
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20).delay(0.1)) {
            orbScale = 1.0
        }

        // Start refresh
        Task {
            await onRefresh()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func completeRefresh() {
        // Success animation
        HapticManager.shared.notification(.success)

        withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
            showSuccess = true
            orbScale = 1.3
        }

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20).delay(0.15)) {
            orbScale = 1.0
        }

        // Hide after delay
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                showSuccess = false
                pullProgress = 0
                hasTriggered = false
            }
        }
    }

    private func startSpinAnimation() {
        guard !reduceMotion else { return }

        orbRotation = 0
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Refreshable View Wrapper

/// Convenient wrapper that combines GlassPullToRefresh with common patterns
public struct GlassRefreshableView<Content: View>: View {

    @Binding var isLoading: Bool
    let onRefresh: () async -> Void
    @ViewBuilder let content: () -> Content

    public init(
        isLoading: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self._isLoading = isLoading
        self.onRefresh = onRefresh
        self.content = content
    }

    public var body: some View {
        GlassPullToRefresh(
            isRefreshing: $isLoading,
            onRefresh: onRefresh,
            content: content,
        )
    }
}

// MARK: - View Extension

extension View {
    /// Adds glass-styled pull-to-refresh behavior
    public func glassPullToRefresh(
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
    ) -> some View {
        GlassPullToRefresh(
            isRefreshing: isRefreshing,
            onRefresh: onRefresh,
        ) {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var isRefreshing = false
        @State private var items = (1 ... 20).map { "Item \($0)" }

        var body: some View {
            GlassPullToRefresh(
                isRefreshing: $isRefreshing,
                onRefresh: {
                    try? await Task.sleep(for: .seconds(2))
                },
            ) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.DesignSystem.glassBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewContainer()
}
