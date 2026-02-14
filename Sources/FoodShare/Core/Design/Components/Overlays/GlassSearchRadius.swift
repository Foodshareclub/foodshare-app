//
//  GlassSearchRadius.swift
//  Foodshare
//
//  Liquid Glass v27 - Search Radius Overlay
//  Animated circular overlay for visualizing search radius on maps
//

import SwiftUI
#if !SKIP
import MapKit
#endif
import FoodShareDesignSystem

// MARK: - Glass Search Radius

/// An animated circular overlay for visualizing search radius on maps
///
/// Features:
/// - Animated expanding/contracting radius
/// - Glass-styled stroke with gradient
/// - Pulsing fill animation
/// - Drag-to-resize interaction (optional)
/// - Accessibility support for reduce motion
///
/// Example usage:
/// ```swift
/// // Basic radius overlay
/// GlassSearchRadius(
///     center: userLocation,
///     radiusInMeters: 5000,
///     color: .DesignSystem.brandGreen
/// )
///
/// // Interactive resize
/// GlassSearchRadius(
///     center: userLocation,
///     radiusInMeters: $searchRadius,
///     isInteractive: true
/// )
/// ```
struct GlassSearchRadius: View {
    let center: CLLocationCoordinate2D
    @Binding var radiusInMeters: Double
    let color: Color
    let strokeWidth: CGFloat
    let fillOpacity: Double
    let isInteractive: Bool
    let showPulse: Bool
    let confidenceLevel: ConfidenceLevel

    @State private var isAnimating = false
    @State private var pulsePhase: Double = 0
    @State private var isDragging = false
    @State private var dragStartRadius: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    /// Create a static radius overlay
    init(
        center: CLLocationCoordinate2D,
        radiusInMeters: Double,
        color: Color = .DesignSystem.brandGreen,
        strokeWidth: CGFloat = 2,
        fillOpacity: Double = 0.1,
        showPulse: Bool = true,
        confidenceLevel: ConfidenceLevel = .high
    ) {
        self.center = center
        self._radiusInMeters = .constant(radiusInMeters)
        self.color = color
        self.strokeWidth = strokeWidth
        self.fillOpacity = fillOpacity
        self.isInteractive = false
        self.showPulse = showPulse
        self.confidenceLevel = confidenceLevel
    }

    /// Create an interactive radius overlay with binding
    init(
        center: CLLocationCoordinate2D,
        radiusInMeters: Binding<Double>,
        color: Color = .DesignSystem.brandGreen,
        strokeWidth: CGFloat = 2,
        fillOpacity: Double = 0.1,
        isInteractive: Bool = true,
        showPulse: Bool = true,
        confidenceLevel: ConfidenceLevel = .high
    ) {
        self.center = center
        self._radiusInMeters = radiusInMeters
        self.color = color
        self.strokeWidth = strokeWidth
        self.fillOpacity = fillOpacity
        self.isInteractive = isInteractive
        self.showPulse = showPulse
        self.confidenceLevel = confidenceLevel
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pulsing outer ring (for animation)
                if showPulse && !reduceMotion {
                    pulsingRing
                }

                // Main radius circle
                mainCircle

                // Confidence indicator dots
                confidenceIndicator
                    .position(x: geometry.size.width / 2, y: 20)

                // Radius label
                radiusLabel
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Interactive resize handles
                if isInteractive {
                    resizeHandles(in: geometry.size)
                }
            }
        }
        .onAppear {
            if showPulse && !reduceMotion {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    pulsePhase = 1
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var pulsingRing: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(time * 2) + 1) / 2 // 0...1

            Circle()
                .stroke(
                    color.opacity(0.3 * (1 - pulse)),
                    lineWidth: strokeWidth + CGFloat(pulse * 4)
                )
                .scaleEffect(1 + CGFloat(pulse * 0.05))
        }
    }

    private var mainCircle: some View {
        ZStack {
            // Fill with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(fillOpacity),
                            color.opacity(fillOpacity * 0.3),
                            color.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            // Dashed stroke border
            Circle()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        dash: [8, 4]
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            color,
                            color.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Solid inner stroke
            Circle()
                .stroke(color, lineWidth: strokeWidth * 0.5)
                .padding(strokeWidth)
        }
        .shadow(color: color.opacity(0.3), radius: 8)
    }

    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index < confidenceLevel.dots ? color : Color.DesignSystem.glassBorder)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    private var radiusLabel: some View {
        VStack(spacing: Spacing.xxxs) {
            Text(formattedRadius)
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            Text(confidenceLevel.label)
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8)
    }

    @ViewBuilder
    private func resizeHandles(in size: CGSize) -> some View {
        // Cardinal direction handles
        ForEach(0..<4) { index in
            let angle = Double(index) * 90.0
            let radians = angle * .pi / 180

            ResizeHandle(color: color, isDragging: isDragging)
                .position(
                    x: size.width / 2 + cos(radians) * min(size.width, size.height) / 2 * 0.9,
                    y: size.height / 2 + sin(radians) * min(size.width, size.height) / 2 * 0.9
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartRadius = radiusInMeters
                            }

                            // Calculate distance from center
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let distance = sqrt(
                                pow(value.location.x - center.x, 2) +
                                pow(value.location.y - center.y, 2)
                            )

                            // Map screen distance to meters (simplified)
                            let maxScreenRadius = min(size.width, size.height) / 2 * 0.9
                            let ratio = distance / maxScreenRadius
                            let newRadius = dragStartRadius * ratio

                            // Clamp radius
                            radiusInMeters = max(500, min(100000, newRadius))
                        }
                        .onEnded { _ in
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                isDragging = false
                            }
                        }
                )
        }
    }

    // MARK: - Helpers

    private var formattedRadius: String {
        if radiusInMeters >= 1000 {
            let km = radiusInMeters / 1000
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.0f m", radiusInMeters)
        }
    }
}

// MARK: - Resize Handle

private struct ResizeHandle: View {
    let color: Color
    let isDragging: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: color.opacity(0.5), radius: isDragging ? 8 : 4)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isDragging)
    }
}

// MARK: - Confidence Level

extension GlassSearchRadius {
    /// Location confidence level for visual indicator
    enum ConfidenceLevel {
        case high
        case medium
        case low
        case veryLow

        var dots: Int {
            switch self {
            case .high: return 4
            case .medium: return 3
            case .low: return 2
            case .veryLow: return 1
            }
        }

        var label: String {
            switch self {
            case .high: return "GPS Accurate"
            case .medium: return "Approximate"
            case .low: return "Estimated"
            case .veryLow: return "Very Approximate"
            }
        }
    }
}

// MARK: - Map Circle Overlay

/// A MapKit-compatible circle overlay with glass styling
struct GlassMapCircleOverlay: MapContent {
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let color: Color
    let strokeWidth: CGFloat
    let fillOpacity: Double

    init(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        color: Color = .DesignSystem.brandGreen,
        strokeWidth: CGFloat = 2,
        fillOpacity: Double = 0.1
    ) {
        self.center = center
        self.radius = radius
        self.color = color
        self.strokeWidth = strokeWidth
        self.fillOpacity = fillOpacity
    }

    var body: some MapContent {
        MapCircle(center: center, radius: radius)
            .foregroundStyle(color.opacity(fillOpacity))
            .stroke(color, lineWidth: strokeWidth)
    }
}

// MARK: - Preview

#Preview("Glass Search Radius") {
    struct PreviewWrapper: View {
        @State private var radius: Double = 5000

        var body: some View {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Text("Glass Search Radius")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    // Static radius
                    GlassSearchRadius(
                        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusInMeters: 2500,
                        color: .DesignSystem.brandGreen,
                        confidenceLevel: .high
                    )
                    .frame(width: 200, height: 200)

                    // Interactive radius
                    VStack {
                        Text("Drag handles to resize")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)

                        GlassSearchRadius(
                            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                            radiusInMeters: $radius,
                            color: .DesignSystem.brandTeal,
                            isInteractive: true,
                            confidenceLevel: .medium
                        )
                        .frame(width: 250, height: 250)
                    }

                    // Different confidence levels
                    HStack(spacing: Spacing.lg) {
                        ForEach([
                            GlassSearchRadius.ConfidenceLevel.high,
                            .medium,
                            .low,
                            .veryLow
                        ], id: \.dots) { level in
                            GlassSearchRadius(
                                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                radiusInMeters: 1000,
                                color: confidenceColor(for: level),
                                showPulse: false,
                                confidenceLevel: level
                            )
                            .frame(width: 80, height: 80)
                        }
                    }
                }
                .padding()
            }
        }

        private func confidenceColor(for level: GlassSearchRadius.ConfidenceLevel) -> Color {
            switch level {
            case .high: return .DesignSystem.brandGreen
            case .medium: return .DesignSystem.brandTeal
            case .low: return .DesignSystem.brandOrange
            case .veryLow: return .DesignSystem.error
            }
        }
    }

    return PreviewWrapper()
}
