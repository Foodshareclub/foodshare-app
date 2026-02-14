import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass FPS Overlay

/// Debug overlay showing real-time frame rate information
/// Only visible in DEBUG builds
public struct GlassFPSOverlay: View {

    // MARK: - Properties

    @State private var monitor = FrameRateMonitor.shared
    @State private var isExpanded = false
    @State private var position = CGPoint(x: 80, y: 100)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    public var body: some View {
        #if DEBUG
            overlayContent
                .position(position)
                .gesture(dragGesture)
                .onAppear {
                    monitor.startMonitoring()
                }
                .onDisappear {
                    monitor.stopMonitoring()
                }
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Compact header (always visible)
            compactHeader

            // Expanded details
            if isExpanded {
                expandedDetails
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity,
                    ))
            }
        }
        .padding(Spacing.sm)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.large))
        .shadow(color: tierColor.opacity(0.3), radius: 10, x: 0, y: 5)
        .animation(.interpolatingSpring(stiffness: 400, damping: 30), value: isExpanded)
    }

    private var compactHeader: some View {
        HStack(spacing: Spacing.xs) {
            // FPS indicator circle
            Circle()
                .fill(tierColor)
                .frame(width: 8, height: 8)

            // FPS value
            Text("\(Int(monitor.currentFPS))")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText())

            Text("FPS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))

            if isExpanded {
                Spacer()

                // Close button
                Button {
                    withAnimation {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
        }
        .onTapGesture {
            HapticManager.light()
            withAnimation {
                isExpanded.toggle()
            }
        }
    }

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Divider()
                .background(Color.white.opacity(0.2))

            // Average FPS
            detailRow(
                label: "Average",
                value: String(format: "%.1f", monitor.averageFPS),
                suffix: "FPS",
            )

            // Dropped frames
            detailRow(
                label: "Dropped",
                value: "\(monitor.droppedFrameCount)",
                suffix: "frames",
                valueColor: monitor.droppedFrameCount > 0 ? .DesignSystem.warning : .white,
            )

            // Device info
            detailRow(
                label: "Target",
                value: "\(Int(monitor.targetFrameRate))",
                suffix: monitor.isProMotionDevice ? "Hz ProMotion" : "Hz",
            )

            // Performance tier
            HStack {
                Text("Status")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.6))

                Spacer()

                Text(monitor.performanceTier.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tierColor)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Reset button
            Button {
                HapticManager.medium()
                monitor.resetMetrics()
            } label: {
                Text("Reset")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(width: 140)
    }

    private func detailRow(
        label: String,
        value: String,
        suffix: String,
        valueColor: Color = .white,
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.6))

            Spacer()

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText())

                Text(suffix)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.large)
                .fill(Color.black.opacity(0.7))

            RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.large)
                .fill(.ultraThinMaterial.opacity(0.3))

            RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.medium : CornerRadius.large)
                .strokeBorder(tierColor.opacity(0.5), lineWidth: 1)
        }
    }

    private var tierColor: Color {
        switch monitor.performanceTier {
        case .excellent: .green
        case .good: .yellow
        case .poor: .orange
        case .critical: .red
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                position = value.location
            }
    }
}

// MARK: - FPS Overlay Modifier

/// Modifier to add FPS overlay to any view
public struct FPSOverlayModifier: ViewModifier {
    let isEnabled: Bool

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                if isEnabled {
                    GlassFPSOverlay()
                }
            }
    }
}

extension View {
    /// Adds a debug FPS overlay to the view
    /// - Parameter enabled: Whether the overlay is visible (default: true in DEBUG)
    public func fpsOverlay(enabled: Bool = true) -> some View {
        #if DEBUG
            modifier(FPSOverlayModifier(isEnabled: enabled))
        #else
            self
        #endif
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack {
                Text("FPS Overlay Demo")
                    .font(.DesignSystem.headlineLarge)
            }
        }
        .fpsOverlay()
    }

    #Preview("Expanded") {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            GlassFPSOverlay()
                .position(x: 200, y: 300)
        }
    }
#endif
