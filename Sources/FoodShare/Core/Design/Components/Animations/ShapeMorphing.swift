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


#if !SKIP
import SwiftUI

// MARK: - Morph Shape Type

/// Defines the target shape for morphing animations
enum MorphShapeType: Equatable, Sendable {
    case circle
    case roundedRect(cornerRadius: CGFloat)
    case squircle(smoothing: CGFloat) // iOS-style continuous corners
    case square
    case custom(cornerRadius: CGFloat, smoothing: CGFloat)

    /// Default corner radius for this shape type
    var effectiveCornerRadius: CGFloat {
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
    var smoothing: CGFloat {
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
struct MorphableShape: Shape, Animatable {
    var cornerRadius: CGFloat
    var smoothing: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, smoothing) }
        set {
            cornerRadius = newValue.first
            smoothing = newValue.second
        }
    }

    init(cornerRadius: CGFloat = 0, smoothing: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.smoothing = smoothing
    }

    init(type: MorphShapeType) {
        self.cornerRadius = type.effectiveCornerRadius
        self.smoothing = type.smoothing
    }

    func path(in rect: CGRect) -> Path {
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
struct MorphingContainer<Content: View>: View {
    let content: Content
    let shape: MorphShapeType
    let animation: Animation

    @State private var currentRadius: CGFloat = 0
    @State private var currentSmoothing: CGFloat = 0

    init(
        shape: MorphShapeType,
        animation: Animation = ProMotionAnimation.smooth,
        @ViewBuilder content: () -> Content,
    ) {
        self.shape = shape
        self.animation = animation
        self.content = content()
    }

    var body: some View {
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
struct InteractiveMorphView<Content: View>: View {
    let content: Content
    let normalShape: MorphShapeType
    let pressedShape: MorphShapeType
    let normalScale: CGFloat
    let pressedScale: CGFloat

    @State private var isPressed = false
    @State private var cornerRadius: CGFloat = 0
    @State private var smoothing: CGFloat = 0
    @State private var scale: CGFloat = 1

    init(
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

    var body: some View {
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
struct PathMorphShape: Shape, Animatable {
    var progress: CGFloat
    let startPath: Path
    let endPath: Path

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    init(progress: CGFloat, startPath: Path, endPath: Path) {
        self.progress = progress
        self.startPath = startPath
        self.endPath = endPath
    }

    func path(in rect: CGRect) -> Path {
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
struct AvatarMorphView: View {
    let imageURL: URL?
    let isExpanded: Bool
    let collapsedSize: CGFloat
    let expandedSize: CGFloat

    @State private var cornerRadius: CGFloat = 0
    @State private var size: CGFloat = 0

    init(
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

    var body: some View {
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
struct CardExpansionMorph<CompactContent: View, ExpandedContent: View>: View {
    let isExpanded: Bool
    let compactContent: CompactContent
    let expandedContent: ExpandedContent
    let namespace: Namespace.ID

    @State private var cornerRadius: CGFloat = CornerRadius.large

    init(
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

    var body: some View {
        Group {
            if isExpanded {
                expandedContent
                    .clipShape(MorphableShape(cornerRadius: cornerRadius))
                    #if !SKIP
                    .matchedGeometryEffect(id: "card", in: namespace)
                    #endif
            } else {
                compactContent
                    .clipShape(MorphableShape(cornerRadius: cornerRadius))
                    #if !SKIP
                    .matchedGeometryEffect(id: "card", in: namespace)
                    #endif
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
struct LiquidMorphEffect: View {
    let isActive: Bool
    let baseColor: Color
    let size: CGFloat

    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0

    init(isActive: Bool = true, baseColor: Color = .DesignSystem.brandGreen, size: CGFloat = 100) {
        self.isActive = isActive
        self.baseColor = baseColor
        self.size = size
    }

    var body: some View {
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
    func morphClip(_ shape: MorphShapeType, animation: Animation = ProMotionAnimation.smooth) -> some View {
        MorphingContainer(shape: shape, animation: animation) {
            self
        }
    }

    /// Apply interactive morphing on press
    func interactiveMorph(
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
    static let card = MorphShapeType.roundedRect(cornerRadius: CornerRadius.large)

    /// iOS-style app icon shape
    static let appIcon = MorphShapeType.squircle(smoothing: 0.6)

    /// Avatar shape (circle)
    static let avatar = MorphShapeType.circle

    /// Button shape
    static let button = MorphShapeType.roundedRect(cornerRadius: CornerRadius.medium)

    /// Full-screen modal shape
    static let modal = MorphShapeType.roundedRect(cornerRadius: CornerRadius.xxl)

    /// Sharp edge shape
    static let sharp = MorphShapeType.square
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
                                .frame(width: 150.0, height: 150)
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
                                .frame(width: 150.0, height: 100)
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
                            .frame(height: 150.0)
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

#endif
