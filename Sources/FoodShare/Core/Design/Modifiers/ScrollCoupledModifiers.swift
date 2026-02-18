
#if !SKIP
import SwiftUI

// MARK: - Scroll Offset Reader

/// Preference key for tracking scroll offset
public struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) public static var defaultValue: CGFloat = 0

    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Coupled Parallax

/// Modifier that creates parallax effect based on scroll position
public struct ScrollParallaxModifier: ViewModifier {

    let intensity: CGFloat
    let direction: ParallaxDirection
    let minOffset: CGFloat
    let maxOffset: CGFloat

    @State private var scrollOffset: CGFloat = 0

    public enum ParallaxDirection {
        case vertical
        case horizontal
        case both
    }

    public func body(content: Content) -> some View {
        content
            .offset(parallaxOffset)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geometry.frame(in: .named("scrollParallax")).origin.y,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
    }

    private var parallaxOffset: CGSize {
        let clampedOffset = max(minOffset, min(maxOffset, scrollOffset * intensity))

        switch direction {
        case .vertical:
            return CGSize(width: 0, height: clampedOffset)
        case .horizontal:
            return CGSize(width: clampedOffset, height: 0)
        case .both:
            return CGSize(width: clampedOffset, height: clampedOffset)
        }
    }
}

extension View {
    /// Applies parallax effect based on scroll position
    public func scrollParallax(
        intensity: CGFloat = 0.5,
        direction: ScrollParallaxModifier.ParallaxDirection = .vertical,
        minOffset: CGFloat = -100,
        maxOffset: CGFloat = 100,
    ) -> some View {
        modifier(ScrollParallaxModifier(
            intensity: intensity,
            direction: direction,
            minOffset: minOffset,
            maxOffset: maxOffset,
        ))
    }
}

// MARK: - Scroll Collapse Header

/// Modifier that collapses a header view based on scroll position
public struct ScrollCollapseModifier<CollapsedContent: View>: ViewModifier {

    let threshold: CGFloat
    let collapsedHeight: CGFloat
    @ViewBuilder let collapsed: () -> CollapsedContent

    @State private var scrollOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            let progress = min(1.0, max(0.0, scrollOffset / threshold))
            let height = geometry.size.height - (geometry.size.height - collapsedHeight) * progress

            ZStack {
                // Expanded content
                content
                    .opacity(1 - progress)
                    .scaleEffect(1 - progress * 0.1, anchor: .top)

                // Collapsed content
                collapsed()
                    .opacity(progress)
                    .scaleEffect(0.9 + progress * 0.1, anchor: .top)
            }
            .frame(height: height)
            .clipped()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -proxy.frame(in: .named("scrollCollapse")).origin.y,
                    )
                },
            )
        }
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            scrollOffset = value
        }
    }
}

extension View {
    /// Collapses to a different view when scrolling past threshold
    public func scrollCollapse(
        threshold: CGFloat = 100,
        collapsedHeight: CGFloat = 60,
        @ViewBuilder collapsed: @escaping () -> some View,
    ) -> some View {
        modifier(ScrollCollapseModifier(
            threshold: threshold,
            collapsedHeight: collapsedHeight,
            collapsed: collapsed,
        ))
    }
}

// MARK: - Scroll Progress Indicator

/// Modifier that provides scroll progress to a custom indicator
public struct ScrollProgressModifier<Indicator: View>: ViewModifier {

    let range: ClosedRange<CGFloat>
    @ViewBuilder let indicator: (CGFloat) -> Indicator

    @State private var scrollOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                indicator(progress)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geometry.frame(in: .named("scrollProgress")).origin.y,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
    }

    private var progress: CGFloat {
        let normalizedOffset = scrollOffset - range.lowerBound
        let totalRange = range.upperBound - range.lowerBound
        return min(1.0, max(0.0, normalizedOffset / totalRange))
    }
}

extension View {
    /// Provides scroll progress to a custom indicator view
    public func scrollProgress(
        range: ClosedRange<CGFloat> = 0 ... 200,
        @ViewBuilder indicator: @escaping (CGFloat) -> some View,
    ) -> some View {
        modifier(ScrollProgressModifier(range: range, indicator: indicator))
    }
}

// MARK: - Scroll Blur Header

/// Modifier that increases blur as user scrolls
public struct ScrollBlurModifier: ViewModifier {

    let maxBlur: CGFloat
    let threshold: CGFloat

    @State private var scrollOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geometry.frame(in: .named("scrollBlur")).origin.y,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
    }

    private var blurRadius: CGFloat {
        let progress = min(1.0, max(0.0, scrollOffset / threshold))
        return progress * maxBlur
    }
}

extension View {
    /// Increases blur as the user scrolls
    public func scrollBlur(
        maxBlur: CGFloat = 10,
        threshold: CGFloat = 100,
    ) -> some View {
        modifier(ScrollBlurModifier(maxBlur: maxBlur, threshold: threshold))
    }
}

// MARK: - Scroll Scale Header

/// Modifier that scales content based on scroll (for stretchy headers)
public struct ScrollScaleModifier: ViewModifier {

    let minScale: CGFloat
    let maxScale: CGFloat
    let anchor: UnitPoint

    @State private var scrollOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        GeometryReader { _ in
            content
                .scaleEffect(scale, anchor: anchor)
                .offset(y: scrollOffset < 0 ? scrollOffset / 2 : 0)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -proxy.frame(in: .named("scrollScale")).origin.y,
                        )
                    },
                )
        }
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            scrollOffset = value
        }
    }

    private var scale: CGFloat {
        if scrollOffset < 0 {
            // Pulling down - scale up
            let pullProgress = abs(scrollOffset) / 100
            return min(maxScale, 1 + pullProgress * 0.3)
        } else {
            // Scrolling up - scale down
            let scrollProgress = scrollOffset / 200
            return max(minScale, 1 - scrollProgress * 0.2)
        }
    }
}

extension View {
    /// Scales content based on scroll position (stretchy header effect)
    public func scrollScale(
        minScale: CGFloat = 0.8,
        maxScale: CGFloat = 1.3,
        anchor: UnitPoint = .center,
    ) -> some View {
        modifier(ScrollScaleModifier(
            minScale: minScale,
            maxScale: maxScale,
            anchor: anchor,
        ))
    }
}

// MARK: - Scroll Fade Header

/// Modifier that fades content as user scrolls
public struct ScrollFadeModifier: ViewModifier {

    let fadeRange: ClosedRange<CGFloat>
    let fadeIn: Bool // true = fade in as scroll, false = fade out

    @State private var scrollOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geometry.frame(in: .named("scrollFade")).origin.y,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
    }

    private var opacity: Double {
        let progress = (scrollOffset - fadeRange.lowerBound) / (fadeRange.upperBound - fadeRange.lowerBound)
        let clampedProgress = min(1.0, max(0.0, progress))
        return fadeIn ? clampedProgress : 1 - clampedProgress
    }
}

extension View {
    /// Fades content based on scroll position
    public func scrollFade(
        range: ClosedRange<CGFloat> = 0 ... 100,
        fadeIn: Bool = false,
    ) -> some View {
        modifier(ScrollFadeModifier(fadeRange: range, fadeIn: fadeIn))
    }
}

// MARK: - Scroll Offset Reader View

/// A view that reads scroll offset and provides it to its content
public struct ScrollOffsetReader<Content: View>: View {

    @Binding var offset: CGFloat
    let coordinateSpace: String
    @ViewBuilder let content: () -> Content

    public init(
        offset: Binding<CGFloat>,
        coordinateSpace: String = "scroll",
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self._offset = offset
        self.coordinateSpace = coordinateSpace
        self.content = content
    }

    public var body: some View {
        content()
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geometry.frame(in: .named(coordinateSpace)).origin.y,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                offset = value
            }
    }
}

// MARK: - Preview

#Preview("Parallax") {
    ScrollView {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.DesignSystem.brandGreen)
                .frame(height: 200.0)
                .scrollParallax(intensity: 0.3)

            LazyVStack {
                ForEach(0 ..< 20, id: \.self) { i in
                    Text("Item \(i)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.glassBackground)
                }
            }
            .padding()
        }
    }
    .coordinateSpace(name: "scrollParallax")
}

#Preview("Scale Header") {
    ScrollView {
        VStack(spacing: 0) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.DesignSystem.brandGreen)
                .frame(height: 200.0)
                .frame(maxWidth: .infinity)
                .background(Color.DesignSystem.glassBackground)
                .scrollScale()

            LazyVStack {
                ForEach(0 ..< 20, id: \.self) { i in
                    Text("Item \(i)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.glassBackground)
                }
            }
            .padding()
        }
    }
    .coordinateSpace(name: "scrollScale")
}

#endif
