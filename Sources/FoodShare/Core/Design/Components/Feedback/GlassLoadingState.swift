//
//  GlassLoadingState.swift
//  Foodshare
//
//  Unified loading state component with multiple style variants
//  Supports spinner, shimmer, skeleton, and glass pulse animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - GlassLoadingState

/// A unified loading state component with multiple visual styles
/// Optimized for 120fps ProMotion and accessibility compliance
struct GlassLoadingState: View {
    let style: Style
    let message: String?
    let showBackground: Bool

    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Style Enum

    enum Style {
        /// Standard spinning indicator
        case spinner

        /// Shimmer effect across content
        case shimmer

        /// Skeleton placeholder shapes
        case skeleton(SkeletonLayout)

        /// Pulsing glass effect
        case glassPulse

        /// Full-screen loading overlay
        case fullScreen

        /// Inline compact loading
        case inline
    }

    enum SkeletonLayout {
        case listingCard
        case profileCard
        case messageRow
        case grid(columns: Int, rows: Int)
        case custom([SkeletonShape])
    }

    struct SkeletonShape: Identifiable {
        let id = UUID()
        let type: ShapeType
        let width: CGFloat?
        let height: CGFloat

        enum ShapeType {
            case rectangle
            case circle
            case capsule
        }

        static func line(width: CGFloat? = nil, height: CGFloat = 16) -> SkeletonShape {
            SkeletonShape(type: .rectangle, width: width, height: height)
        }

        static func circle(size: CGFloat) -> SkeletonShape {
            SkeletonShape(type: .circle, width: size, height: size)
        }

        static func pill(width: CGFloat, height: CGFloat = 24) -> SkeletonShape {
            SkeletonShape(type: .capsule, width: width, height: height)
        }
    }

    // MARK: - Initialization

    init(style: Style = .spinner, message: String? = nil, showBackground: Bool = true) {
        self.style = style
        self.message = message
        self.showBackground = showBackground
    }

    var body: some View {
        Group {
            switch style {
            case .spinner:
                spinnerContent
            case .shimmer:
                shimmerContent
            case let .skeleton(layout):
                skeletonContent(layout: layout)
            case .glassPulse:
                glassPulseContent
            case .fullScreen:
                fullScreenContent
            case .inline:
                inlineContent
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Spinner Content

    private var spinnerContent: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                    .scaleEffect(pulseScale)

                // Animated ring
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.DesignSystem.brandGreen,
                                Color.DesignSystem.brandBlue,
                                Color.DesignSystem.brandGreen.opacity(0.3)
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))

                // Center icon
                Image(systemName: "fork.knife")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .drawingGroup()

            if let message {
                loadingMessage(message)
            }
        }
        .padding(Spacing.lg)
        .modifier(ConditionalBackground(show: showBackground))
    }

    // MARK: - Shimmer Content

    private var shimmerContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Shimmer gradient
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .offset(x: shimmerOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = geometry.size.width + 100
                    }
                }
            }
        }
    }

    // MARK: - Skeleton Content

    @ViewBuilder
    private func skeletonContent(layout: SkeletonLayout) -> some View {
        switch layout {
        case .listingCard:
            listingCardSkeleton
        case .profileCard:
            profileCardSkeleton
        case .messageRow:
            messageRowSkeleton
        case let .grid(columns, rows):
            skeletonGrid(columns: columns, rows: rows)
        case let .custom(shapes):
            customSkeletonContent(shapes: shapes)
        }
    }

    // MARK: - Built-in Skeleton Layouts

    private var listingCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 160)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 120, height: 14)

                HStack {
                    Capsule()
                        .fill(skeletonGradient)
                        .frame(width: 60, height: 24)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 40, height: 12)
                }
            }
            .padding(Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(shimmerOverlay)
    }

    private var profileCardSkeleton: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(skeletonGradient)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 120, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 80, height: 12)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(shimmerOverlay)
    }

    private var messageRowSkeleton: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(skeletonGradient)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 100, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
        )
        .overlay(shimmerOverlay)
    }

    private func skeletonGrid(columns: Int, rows: Int) -> some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: columns)

        return LazyVGrid(columns: gridItems, spacing: Spacing.md) {
            ForEach(0..<(columns * rows), id: \.self) { _ in
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(skeletonGradient)
                    .frame(height: 100)
            }
        }
        .overlay(shimmerOverlay)
    }

    private func customSkeletonContent(shapes: [SkeletonShape]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(shapes) { shape in
                skeletonShapeView(shape)
            }
        }
        .padding(Spacing.md)
        .modifier(ConditionalBackground(show: showBackground))
        .overlay(shimmerOverlay)
    }

    @ViewBuilder
    private func skeletonShapeView(_ shape: SkeletonShape) -> some View {
        switch shape.type {
        case .rectangle:
            if let width = shape.width {
                RoundedRectangle(cornerRadius: shape.height / 2)
                    .fill(skeletonGradient)
                    .frame(width: width, height: shape.height)
            } else {
                RoundedRectangle(cornerRadius: shape.height / 2)
                    .fill(skeletonGradient)
                    .frame(height: shape.height)
            }
        case .circle:
            Circle()
                .fill(skeletonGradient)
                .frame(width: shape.width, height: shape.height)
        case .capsule:
            Capsule()
                .fill(skeletonGradient)
                .frame(width: shape.width, height: shape.height)
        }
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 150)
            .offset(x: shimmerOffset)
            .onAppear {
                shimmerOffset = -150
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = geometry.size.width + 150
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Glass Pulse Content

    private var glassPulseContent: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                // Pulsing circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.3 - Double(index) * 0.1),
                                    Color.DesignSystem.brandBlue.opacity(0.2 - Double(index) * 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 60 + CGFloat(index) * 30, height: 60 + CGFloat(index) * 30)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            reduceMotion ? .none :
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }

                // Center content
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "hourglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(rotationAngle / 4))
                    )
            }
            .drawingGroup()

            if let message {
                loadingMessage(message)
            }
        }
        .padding(Spacing.lg)
        .modifier(ConditionalBackground(show: showBackground))
    }

    // MARK: - Full Screen Content

    private var fullScreenContent: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: Spacing.lg) {
                spinnerContent
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
    }

    // MARK: - Inline Content

    private var inlineContent: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(Color.DesignSystem.brandGreen)

            if let message {
                Text(message)
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Views

    private func loadingMessage(_ text: String) -> some View {
        Text(text)
            .font(.DesignSystem.bodySmall)
            .foregroundColor(.DesignSystem.textSecondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Animations

    private func startAnimations() {
        guard !reduceMotion else { return }

        // Rotation animation for spinner
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Glass pulse animation
        withAnimation(.easeOut(duration: 0.1)) {
            isAnimating = true
        }
    }
}

// MARK: - Conditional Background Modifier

private struct ConditionalBackground: ViewModifier {
    let show: Bool

    func body(content: Content) -> some View {
        if show {
            content
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                        )
                )
        } else {
            content
        }
    }
}

// MARK: - Convenience Constructors

extension GlassLoadingState {
    /// Standard loading spinner with optional message
    static func spinner(message: String? = nil) -> GlassLoadingState {
        GlassLoadingState(style: .spinner, message: message)
    }

    /// Inline loading indicator
    static func inline(message: String? = "Loading...") -> GlassLoadingState {
        GlassLoadingState(style: .inline, message: message)
    }

    /// Full-screen loading overlay
    static func fullScreen(message: String? = nil) -> GlassLoadingState {
        GlassLoadingState(style: .fullScreen, message: message)
    }

    /// Glass pulse animation
    static func pulse(message: String? = nil) -> GlassLoadingState {
        GlassLoadingState(style: .glassPulse, message: message)
    }

    /// Skeleton loading for listing cards
    static var listingSkeleton: GlassLoadingState {
        GlassLoadingState(style: .skeleton(.listingCard), showBackground: false)
    }

    /// Skeleton loading for profile cards
    static var profileSkeleton: GlassLoadingState {
        GlassLoadingState(style: .skeleton(.profileCard), showBackground: false)
    }

    /// Skeleton grid loading
    static func skeletonGrid(columns: Int = 2, rows: Int = 3) -> GlassLoadingState {
        GlassLoadingState(style: .skeleton(.grid(columns: columns, rows: rows)), showBackground: false)
    }
}

// MARK: - View Extension

extension View {
    /// Shows a loading overlay when the condition is true
    @ViewBuilder
    func glassLoading(
        when isLoading: Bool,
        style: GlassLoadingState.Style = .spinner,
        message: String? = nil
    ) -> some View {
        ZStack {
            self
                .opacity(isLoading ? 0.5 : 1)
                .disabled(isLoading)

            if isLoading {
                GlassLoadingState(style: style, message: message)
            }
        }
    }
}

// MARK: - Previews

#Preview("Loading Styles") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            GlassLoadingState.spinner(message: "Finding food near you...")

            GlassLoadingState.pulse(message: "Processing...")

            GlassLoadingState.inline(message: "Loading more...")

            GlassLoadingState.listingSkeleton

            GlassLoadingState.profileSkeleton

            GlassLoadingState.skeletonGrid(columns: 2, rows: 2)
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#Preview("Full Screen Loading") {
    ZStack {
        Color.DesignSystem.background
            .ignoresSafeArea()

        VStack {
            Text("Content behind loading")
                .font(.DesignSystem.headlineMedium)
                .foregroundColor(.DesignSystem.text)
        }

        GlassLoadingState.fullScreen(message: "Please wait...")
    }
}

#Preview("Loading Modifier") {
    @Previewable @State var isLoading = true

    VStack(spacing: Spacing.lg) {
        Button("Toggle Loading") {
            isLoading.toggle()
        }
        .buttonStyle(.borderedProminent)

        VStack(spacing: Spacing.md) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.DesignSystem.brandGreen.opacity(0.3))
                    .frame(height: 100)
                    .overlay(Text("Item \(index + 1)"))
            }
        }
        .glassLoading(when: isLoading, message: "Loading items...")
    }
    .padding()
    .background(Color.DesignSystem.background)
}
