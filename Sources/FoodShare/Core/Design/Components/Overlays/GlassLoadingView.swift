//
//  GlassLoadingView.swift
//  Foodshare
//
//  Liquid Glass v27 Loading Overlay
//  Optimized for 120Hz ProMotion displays with GPU rasterization
//


#if !SKIP
import SwiftUI

struct GlassLoadingView: View {
    let message: String

    @State private var isVisible = false

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: Spacing.md) {
                // 120Hz ProMotion optimized spinner using TimelineView
                ProMotionSpinner()
                    .frame(width: 60.0, height: 60)

                Text(message)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)
            }
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .padding(Spacing.xl)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusXL)
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif

                    RoundedRectangle(cornerRadius: Spacing.radiusXL)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassHighlight,
                                    Color.DesignSystem.glassBorder
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        )

                    RoundedRectangle(cornerRadius: Spacing.radiusXL)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center,
                            ),
                        )
                },
            )
            .shadow(color: Color.black.opacity(0.2), radius: 30, y: 15)
            .drawingGroup() // GPU rasterization for glass card
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 250, damping: 20)) {
                isVisible = true
            }
        }
    }
}

// MARK: - ProMotion 120Hz Optimized Spinner

/// A spinner component optimized for ProMotion displays using TimelineView
/// Provides frame-perfect 120fps animation on capable devices
struct ProMotionSpinner: View {
    /// Animation duration in seconds
    let duration: Double

    /// Track color
    let trackColor: Color

    /// Progress gradient colors
    let gradientColors: [Color]

    /// Line width
    let lineWidth: CGFloat

    init(
        duration: Double = 1.0,
        trackColor: Color = Color.DesignSystem.brandGreen.opacity(0.2),
        gradientColors: [Color] = [
            Color.DesignSystem.brandGreen,
            Color.DesignSystem.brandBlue,
            Color.DesignSystem.brandGreen.opacity(0.3)
        ],
        lineWidth: CGFloat = 4
    ) {
        self.duration = duration
        self.trackColor = trackColor
        self.gradientColors = gradientColors
        self.lineWidth = lineWidth
    }

    var body: some View {
        #if !SKIP
        // TimelineView with animation schedule for 120Hz ProMotion
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth / 2

                // Calculate rotation based on elapsed time
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let rotation = (elapsed.truncatingRemainder(dividingBy: duration)) / duration * 360

                // Draw track
                let trackPath = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                context.stroke(
                    trackPath,
                    with: .color(trackColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

                // Draw spinning arc
                let arcPath = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(rotation - 90),
                        endAngle: .degrees(rotation + 162), // 0.7 * 360 = 252, so arc spans 252 degrees
                        clockwise: false
                    )
                }

                // Create gradient for the arc
                let gradient = Gradient(colors: gradientColors)
                context.stroke(
                    arcPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0.0, y: 0.0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .shadow(
            color: Color.DesignSystem.brandGreen.opacity(0.5),
            radius: 8,
            y: 4
        )
        #else
        ProgressView()
        #endif
    }
}

// MARK: - ProMotion Pulse Ring

/// A pulsing ring effect optimized for 120Hz ProMotion displays
struct ProMotionPulseRing: View {
    let color: Color
    let duration: Double

    init(color: Color = Color.DesignSystem.brandGreen, duration: Double = 2.0) {
        self.color = color
        self.duration = duration
    }

    var body: some View {
        #if !SKIP
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = (elapsed.truncatingRemainder(dividingBy: duration)) / duration

                // Draw multiple expanding rings
                for i in 0..<3 {
                    let ringPhase = (phase + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                    let maxRadius = min(size.width, size.height) / 2
                    let radius = maxRadius * ringPhase
                    let opacity = 1.0 - ringPhase

                    let ringPath = Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360),
                            clockwise: false
                        )
                    }

                    context.stroke(
                        ringPath,
                        with: .color(color.opacity(opacity * 0.6)),
                        style: StrokeStyle(lineWidth: 2)
                    )
                }
            }
        }
        #else
        ProgressView()
        #endif
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassLoadingView(message: "Sharing food...")
    }
}

#endif
