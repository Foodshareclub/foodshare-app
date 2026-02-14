//
//  ShapeMorphing.swift
//  FoodShare
//
//  Animatable shape morphing for smooth transitions.
//  Supports circle → rounded rect → square interpolation with
//  path-based animations optimized for 120Hz ProMotion displays.
//
//  Usage:
//  - Card → Detail view transitions
//  - Avatar → Profile expansions
//  - Icon state changes
//  - Interactive shape feedback
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Morph Shape Type

/// Defines the target shape for morphing animations
public enum MorphShapeType: Equatable, Sendable {
    case circle
    case roundedRect(cornerRadius: CGFloat)
    case squircle(smoothing: CGFloat) // iOS-style continuous corners
    case square
    case custom(cornerRadius: CGFloat, smoothing: CGFloat)

    /// Default corner radius for this shape type
    public var effectiveCornerRadius: CGFloat {
        switch self {
        case .circle:
            .infinity // Will be clamped to half of min dimension
        case let .roundedRect(cornerRadius):
            cornerRadius
        case let .squircle(smoothing):
            CornerRadius.xxl * smoothing
        case .square:
            0
        case let .custom(cornerRadius, _):
            cornerRadius
        }
    }

    /// Smoothing factor for continuous corners (0 = sharp, 1 = full iOS squircle)
    public var smoothing: CGFloat {
        switch self {
        case .circle, .roundedRect, .square:
            0
        case let .squircle(smoothing):
            smoothing
        case let .custom(_, smoothing):
            smoothing
        }
    }
}

// MARK: - Animatable Morph Shape

/// Shape that can smoothly morph between different corner radii
public struct MorphableShape: Shape, Animatable {
    var cornerRadius: CGFloat
    var smoothing: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, smoothing) }
        set {
            cornerRadius = newValue.first
            smoothing = newValue.second
        }
    }

    public init(cornerRadius: CGFloat = 0, smoothing: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.smoothing = smoothing
    }

    public init(type: MorphShapeType) {
        self.cornerRadius = type.effectiveCornerRadius
        self.smoothing = type.smoothing
    }

    public func path(in rect: CGRect) -> Path {
        let minDimension = min(rect.width, rect.height)
        let effectiveRadius = min(cornerRadius, minDimension / 2)

        if smoothing > 0 {
            // Use continuous corner curve for squircle effect
            return Path(
                roundedRect: rect,
                cornerRadius: effectiveRadius,
                style: .continuous,
            )
        } else {
            return Path(
                roundedRect: rect,
                cornerRadius: effectiveRadius,
                style: .circular,
            )
        }
    }
}

// MARK: - Morphing Container View

/// A container that morphs its shape based on state
public struct MorphingContainer<Content: View>: View {
    let content: Content
    let shape: MorphShapeType
    let animation: Animation

    @State private var currentRadius: CGFloat = 0
    @State private var currentSmoothing: CGFloat = 0

    public init(
        shape: MorphShapeType,
        animation: Animation = ProMotionAnimation.smooth,
        @ViewBuilder content: () -> Content,
    ) {
        self.shape = shape
        self.animation = animation
        self.content = content()
    }

    public var body: some View {
        content
            .clipShape(MorphableShape(cornerRadius: currentRadius, smoothing: currentSmoothing))
            .onChange(of: shape, initial: true) { _, newShape in
                withAnimation(animation) {
                    currentRadius = newShape.effectiveCornerRadius
                    currentSmoothing = newShape.smoothing
                }
            }
    }
}

// MARK: - Interactive Morph View

/// View that morphs shape based on press state
public struct InteractiveMorphView<Content: View>: View {
    let content: Content
    let normalShape: MorphShapeType
    let pressedShape: MorphShapeType
    let normalScale: CGFloat
    let pressedScale: CGFloat

    @State private var isPressed = false
    @State private var cornerRadius: CGFloat = 0
    @State private var smoothing: CGFloat = 0
    @State private var scale: CGFloat = 1

    public init(
        normalShape: MorphShapeType = .roundedRect(cornerRadius: CornerRadius.large),
        pressedShape: MorphShapeType = .roundedRect(cornerRadius: CornerRadius.xl),
        normalScale: CGFloat = 1.0,
        pressedScale: CGFloat = 0.95,
        @ViewBuilder content: () -> Content,
    ) {
        self.normalShape = normalShape
        self.pressedShape = pressedShape
        self.normalScale = normalScale
        self.pressedScale = pressedScale
        self.content = content()
    }

    public var body: some View {
        content
            .clipShape(MorphableShape(cornerRadius: cornerRadius, smoothing: smoothing))
            .scaleEffect(scale)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        morphTo(pressedShape, scale: pressedScale)
                        HapticManager.light()
                    }
                    .onEnded { _ in
                        isPressed = false
                        morphTo(normalShape, scale: normalScale)
                    },
            )
            .onAppear {
                cornerRadius = normalShape.effectiveCornerRadius
                smoothing = normalShape.smoothing
                scale = normalScale
            }
    }

    private func morphTo(_ shape: MorphShapeType, scale: CGFloat) {
        withAnimation(ProMotionAnimation.instant) {
            cornerRadius = shape.effectiveCornerRadius
            smoothing = shape.smoothing
            self.scale = scale
        }
    }
}

// MARK: - Path Morphing Shape

/// Shape that interpolates between two arbitrary paths
public struct PathMorphShape: Shape, Animatable {
    var progress: CGFloat
    let startPath: Path
    let endPath: Path

    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    public init(progress: CGFloat, startPath: Path, endPath: Path) {
        self.progress = progress
        self.startPath = startPath
        self.endPath = endPath
    }

    public func path(in rect: CGRect) -> Path {
        // For simple path morphing, interpolate between normalized bounds
        // Complex path morphing would require path segment matching
        if progress <= 0 {
            return startPath
        } else if progress >= 1 {
            return endPath
        }

        // Simple interpolation - blend corner radii if both are rounded rects
        // For more complex paths, you'd need path segment interpolation
        return interpolatePaths(startPath, endPath, progress: progress, in: rect)
    }

    private func interpolatePaths(_ start: Path, _ end: Path, progress: CGFloat, in rect: CGRect) -> Path {
        // Simplified implementation: return the appropriate path based on progress
        // A full implementation would interpolate individual path elements
        progress < 0.5 ? start : end
    }
}

// MARK: - Avatar Morph View

/// Specialized view for avatar → profile image transitions
public struct AvatarMorphView: View {
    let imageURL: URL?
    let isExpanded: Bool
    let collapsedSize: CGFloat
    let expandedSize: CGFloat

    @State private var cornerRadius: CGFloat = 0
    @State private var size: CGFloat = 0

    public init(
        imageURL: URL?,
        isExpanded: Bool,
        collapsedSize: CGFloat = 44,
        expandedSize: CGFloat = 200,
    ) {
        self.imageURL = imageURL
        self.isExpanded = isExpanded
        self.collapsedSize = collapsedSize
        self.expandedSize = expandedSize
    }

    public var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholderView
            case .empty:
                placeholderView
                    .proMotionShimmer()
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(MorphableShape(cornerRadius: cornerRadius))
        .onChange(of: isExpanded, initial: true) { _, expanded in
            withAnimation(ProMotionAnimation.fluid) {
                if expanded {
                    cornerRadius = CornerRadius.large
                    size = expandedSize
                } else {
                    cornerRadius = collapsedSize / 2 // Circle
                    size = collapsedSize
                }
            }
        }
    }

    private var placeholderView: some View {
        Color.DesignSystem.brandGreen.opacity(0.2)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.DesignSystem.brandGreen),
            )
    }
}

// MARK: - Card Expansion Morph

/// Morphing card that expands from compact to full size
public struct CardExpansionMorph<CompactContent: View, ExpandedContent: View>: View {
    let isExpanded: Bool
    let compactContent: CompactContent
    let expandedContent: ExpandedContent
    let namespace: Namespace.ID

    @State private var cornerRadius: CGFloat = CornerRadius.large

    public init(
        isExpanded: Bool,
        namespace: Namespace.ID,
        @ViewBuilder compact: () -> CompactContent,
        @ViewBuilder expanded: () -> ExpandedContent,
    ) {
        self.isExpanded = isExpanded
        self.namespace = namespace
        self.compactContent = compact()
        self.expandedContent = expanded()
    }

    public var body: some View {
        Group {
            if isExpanded {
                expandedContent
                    .clipShape(MorphableShape(cornerRadius: cornerRadius))
                    .matchedGeometryEffect(id: "card", in: namespace)
            } else {
                compactContent
                    .clipShape(MorphableShape(cornerRadius: cornerRadius))
                    .matchedGeometryEffect(id: "card", in: namespace)
            }
        }
        .onChange(of: isExpanded, initial: true) { _, expanded in
            withAnimation(ProMotionAnimation.fluid) {
                cornerRadius = expanded ? CornerRadius.xxl : CornerRadius.large
            }
        }
    }
}

// MARK: - Liquid Morph Effect

/// Advanced liquid-like morphing effect using multiple overlapping shapes
public struct LiquidMorphEffect: View {
    let isActive: Bool
    let baseColor: Color
    let size: CGFloat

    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0

    public init(isActive: Bool = true, baseColor: Color = .DesignSystem.brandGreen, size: CGFloat = 100) {
        self.isActive = isActive
        self.baseColor = baseColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Layer 1 - Slow morphing
            MorphableShape(cornerRadius: size * (0.3 + phase1 * 0.2))
                .fill(baseColor.opacity(0.3))
                .frame(width: size * (1 + phase1 * 0.1), height: size * (1 + phase1 * 0.1))
                .blur(radius: 4)

            // Layer 2 - Medium morphing
            MorphableShape(cornerRadius: size * (0.35 + phase2 * 0.15))
                .fill(baseColor.opacity(0.4))
                .frame(width: size * (0.9 + phase2 * 0.1), height: size * (0.9 + phase2 * 0.1))
                .blur(radius: 2)

            // Layer 3 - Fast morphing
            MorphableShape(cornerRadius: size * (0.4 + phase3 * 0.1))
                .fill(baseColor.opacity(0.6))
                .frame(width: size * (0.8 + phase3 * 0.05), height: size * (0.8 + phase3 * 0.05))
        }
        .onAppear {
            guard isActive else { return }
            startAnimations()
        }
        .onChange(of: isActive) { _, active in
            if active {
                startAnimations()
            }
        }
    }

    private func startAnimations() {
        withAnimation(ProMotionAnimation.gentle.repeatForever(autoreverses: true)) {
            phase1 = 1
        }
        withAnimation(ProMotionAnimation.fluid.repeatForever(autoreverses: true).delay(0.3)) {
            phase2 = 1
        }
        withAnimation(ProMotionAnimation.smooth.repeatForever(autoreverses: true).delay(0.6)) {
            phase3 = 1
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply morphable clipping that animates between shapes
    public func morphClip(_ shape: MorphShapeType, animation: Animation = ProMotionAnimation.smooth) -> some View {
        MorphingContainer(shape: shape, animation: animation) {
            self
        }
    }

    /// Apply interactive morphing on press
    public func interactiveMorph(
        normalShape: MorphShapeType = .roundedRect(cornerRadius: CornerRadius.large),
        pressedShape: MorphShapeType = .roundedRect(cornerRadius: CornerRadius.xl),
        normalScale: CGFloat = 1.0,
        pressedScale: CGFloat = 0.95,
    ) -> some View {
        InteractiveMorphView(
            normalShape: normalShape,
            pressedShape: pressedShape,
            normalScale: normalScale,
            pressedScale: pressedScale,
        ) {
            self
        }
    }
}

// MARK: - Shape Presets

extension MorphShapeType {
    /// Default card shape
    public static let card = MorphShapeType.roundedRect(cornerRadius: CornerRadius.large)

    /// iOS-style app icon shape
    public static let appIcon = MorphShapeType.squircle(smoothing: 0.6)

    /// Avatar shape (circle)
    public static let avatar = MorphShapeType.circle

    /// Button shape
    public static let button = MorphShapeType.roundedRect(cornerRadius: CornerRadius.medium)

    /// Full-screen modal shape
    public static let modal = MorphShapeType.roundedRect(cornerRadius: CornerRadius.xxl)

    /// Sharp edge shape
    public static let sharp = MorphShapeType.square
}

// MARK: - Preview

#if DEBUG
    #Preview("Shape Morphing") {
        struct PreviewContent: View {
            @State private var shapeType: MorphShapeType = .avatar
            @State private var isExpanded = false

            var body: some View {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Shape type selector
                        VStack(spacing: Spacing.md) {
                            Text("Tap to morph")
                                .font(.LiquidGlass.headlineSmall)

                            Color.DesignSystem.brandGreen
                                .frame(width: 150, height: 150)
                                .morphClip(shapeType)
                                .onTapGesture {
                                    withAnimation(ProMotionAnimation.smooth) {
                                        switch shapeType {
                                        case .circle: shapeType = .roundedRect(cornerRadius: CornerRadius.large)
                                        case .roundedRect: shapeType = .squircle(smoothing: 0.6)
                                        case .squircle: shapeType = .square
                                        case .square: shapeType = .circle
                                        case .custom: shapeType = .circle
                                        }
                                    }
                                }
                        }

                        Divider()

                        // Interactive morph
                        VStack(spacing: Spacing.md) {
                            Text("Press and hold")
                                .font(.LiquidGlass.headlineSmall)

                            Color.DesignSystem.brandPink
                                .frame(width: 150, height: 100)
                                .overlay(
                                    Text("Interactive")
                                        .foregroundStyle(.white),
                                )
                                .interactiveMorph()
                        }

                        Divider()

                        // Liquid morph effect
                        VStack(spacing: Spacing.md) {
                            Text("Liquid Effect")
                                .font(.LiquidGlass.headlineSmall)

                            LiquidMorphEffect(
                                isActive: true,
                                baseColor: .DesignSystem.brandTeal,
                                size: 120,
                            )
                            .frame(height: 150)
                        }
                    }
                    .padding()
                }
                .background(Color.DesignSystem.background)
            }
        }

        return PreviewContent()
            .preferredColorScheme(.dark)
    }
#endif
