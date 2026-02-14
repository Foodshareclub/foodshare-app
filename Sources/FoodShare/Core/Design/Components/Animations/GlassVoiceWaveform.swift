//
//  GlassVoiceWaveform.swift
//  Foodshare
//
//  Liquid Glass v27 - Voice Waveform Visualization
//  ProMotion 120Hz optimized audio visualization with Canvas rendering
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Voice Waveform

/// A beautiful voice waveform visualization for voice search
///
/// Features:
/// - Canvas-based 120Hz bar animation
/// - Multiple visualization styles
/// - Smooth amplitude transitions
/// - Glass-styled microphone center
/// - Accessibility support
///
/// Example usage:
/// ```swift
/// GlassVoiceWaveform(
///     isActive: $isListening,
///     amplitude: audioLevel
/// )
///
/// GlassVoiceWaveform(
///     isActive: $isListening,
///     style: .circular,
///     barCount: 24
/// )
/// ```
struct GlassVoiceWaveform: View {
    @Binding var isActive: Bool
    var amplitude: CGFloat
    let style: WaveformStyle
    let barCount: Int
    let primaryColor: Color
    let secondaryColor: Color
    let micSize: CGFloat
    let showMic: Bool

    @State private var animationPhase: Double = 0
    @State private var barHeights: [CGFloat] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Types

    enum WaveformStyle {
        case linear      // Horizontal bars
        case circular    // Bars around a circle
        case mirrored    // Mirrored horizontal bars
        case wave        // Sine wave pattern
    }

    // MARK: - Initialization

    init(
        isActive: Binding<Bool>,
        amplitude: CGFloat = 0.5,
        style: WaveformStyle = .circular,
        barCount: Int = 32,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.error,
        micSize: CGFloat = 60,
        showMic: Bool = true
    ) {
        self._isActive = isActive
        self.amplitude = amplitude
        self.style = style
        self.barCount = barCount
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.micSize = micSize
        self.showMic = showMic
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : 1.0 / 120.0)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                switch style {
                case .linear:
                    drawLinearWaveform(context: context, size: size, date: timeline.date)
                case .circular:
                    drawCircularWaveform(context: context, center: center, size: size, date: timeline.date)
                case .mirrored:
                    drawMirroredWaveform(context: context, size: size, date: timeline.date)
                case .wave:
                    drawWaveWaveform(context: context, size: size, date: timeline.date)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if showMic {
                    microphoneView
                }
            }
        }
        .onAppear {
            barHeights = Array(repeating: 0.3, count: barCount)
        }
        .accessibilityLabel("Voice waveform visualization")
        .accessibilityValue(isActive ? "Active" : "Inactive")
    }

    // MARK: - Microphone View

    private var microphoneView: some View {
        ZStack {
            // Glow effect
            if isActive {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryColor.opacity(0.4),
                                secondaryColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: micSize / 2,
                            endRadius: micSize * 1.5
                        )
                    )
                    .frame(width: micSize * 3, height: micSize * 3)
                    .blur(radius: 10)
            }

            // Glass background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: micSize, height: micSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.DesignSystem.glassBorder,
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            // Microphone icon
            Image(systemName: isActive ? "mic.fill" : "mic")
                .font(.system(size: micSize * 0.4, weight: .medium))
                .foregroundStyle(
                    isActive ? secondaryColor : Color.DesignSystem.textSecondary
                )
                .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isActive)
        }
    }

    // MARK: - Linear Waveform

    private func drawLinearWaveform(context: GraphicsContext, size: CGSize, date: Date) {
        let barWidth: CGFloat = 4
        let spacing: CGFloat = 3
        let totalBarWidth = barWidth + spacing
        let maxHeight = size.height * 0.6
        let centerY = size.height / 2
        let startX = (size.width - CGFloat(barCount) * totalBarWidth) / 2

        let time = date.timeIntervalSinceReferenceDate

        for i in 0..<barCount {
            let phase = time * 3 + Double(i) * 0.2
            let baseHeight = isActive
                ? (sin(phase) * 0.3 + 0.5) * amplitude
                : 0.2

            let height = max(8, baseHeight * maxHeight)

            let rect = CGRect(
                x: startX + CGFloat(i) * totalBarWidth,
                y: centerY - height / 2,
                width: barWidth,
                height: height
            )

            let gradient = Gradient(colors: [
                primaryColor.opacity(0.8),
                secondaryColor.opacity(0.6)
            ])

            context.fill(
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .path(in: rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                )
            )
        }
    }

    // MARK: - Circular Waveform

    private func drawCircularWaveform(context: GraphicsContext, center: CGPoint, size: CGSize, date: Date) {
        let radius: CGFloat = min(size.width, size.height) / 2 - 40
        let innerRadius = micSize / 2 + 15
        let maxBarLength = radius - innerRadius
        let barWidth: CGFloat = 4

        let time = date.timeIntervalSinceReferenceDate

        for i in 0..<barCount {
            let angle = (Double(i) / Double(barCount)) * 2 * .pi - .pi / 2
            let phase = time * 4 + Double(i) * 0.3

            let baseLength = isActive
                ? (sin(phase) * 0.4 + 0.6) * amplitude
                : 0.3

            let barLength = max(8, baseLength * maxBarLength)

            let startPoint = CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            )

            let endPoint = CGPoint(
                x: center.x + cos(angle) * (innerRadius + barLength),
                y: center.y + sin(angle) * (innerRadius + barLength)
            )

            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            let gradient = Gradient(colors: [
                primaryColor.opacity(0.9),
                secondaryColor.opacity(0.7)
            ])

            context.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                ),
                style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
            )
        }
    }

    // MARK: - Mirrored Waveform

    private func drawMirroredWaveform(context: GraphicsContext, size: CGSize, date: Date) {
        let barWidth: CGFloat = 3
        let spacing: CGFloat = 2
        let totalBarWidth = barWidth + spacing
        let maxHeight = size.height * 0.3
        let centerY = size.height / 2
        let startX = (size.width - CGFloat(barCount) * totalBarWidth) / 2

        let time = date.timeIntervalSinceReferenceDate

        for i in 0..<barCount {
            let phase = time * 3.5 + Double(i) * 0.25
            let baseHeight = isActive
                ? (sin(phase) * 0.4 + 0.5) * amplitude
                : 0.15

            let height = max(4, baseHeight * maxHeight)

            // Top bar
            let topRect = CGRect(
                x: startX + CGFloat(i) * totalBarWidth,
                y: centerY - height - 2,
                width: barWidth,
                height: height
            )

            // Bottom bar (mirrored)
            let bottomRect = CGRect(
                x: startX + CGFloat(i) * totalBarWidth,
                y: centerY + 2,
                width: barWidth,
                height: height
            )

            let gradient = Gradient(colors: [
                primaryColor.opacity(0.9),
                secondaryColor.opacity(0.6)
            ])

            context.fill(
                RoundedRectangle(cornerRadius: barWidth / 2).path(in: topRect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: topRect.midX, y: topRect.maxY),
                    endPoint: CGPoint(x: topRect.midX, y: topRect.minY)
                )
            )

            context.fill(
                RoundedRectangle(cornerRadius: barWidth / 2).path(in: bottomRect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: bottomRect.midX, y: bottomRect.minY),
                    endPoint: CGPoint(x: bottomRect.midX, y: bottomRect.maxY)
                )
            )
        }
    }

    // MARK: - Wave Waveform

    private func drawWaveWaveform(context: GraphicsContext, size: CGSize, date: Date) {
        let centerY = size.height / 2
        let waveHeight = size.height * 0.25 * amplitude
        let time = date.timeIntervalSinceReferenceDate

        var path = Path()
        var path2 = Path()

        for x in stride(from: 0, to: size.width, by: 2) {
            let normalizedX = x / size.width
            let phase1 = time * 3 + normalizedX * .pi * 4
            let phase2 = time * 2.5 + normalizedX * .pi * 3 + .pi / 4

            let y1 = centerY + (isActive ? sin(phase1) * waveHeight : sin(normalizedX * .pi * 2) * 5)
            let y2 = centerY + (isActive ? sin(phase2) * waveHeight * 0.7 : sin(normalizedX * .pi * 2 + .pi) * 3)

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y1))
                path2.move(to: CGPoint(x: x, y: y2))
            } else {
                path.addLine(to: CGPoint(x: x, y: y1))
                path2.addLine(to: CGPoint(x: x, y: y2))
            }
        }

        context.stroke(
            path,
            with: .color(primaryColor.opacity(0.8)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )

        context.stroke(
            path2,
            with: .color(secondaryColor.opacity(0.5)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Compact Voice Waveform

/// A smaller waveform for inline use
struct GlassVoiceWaveformCompact: View {
    let isActive: Bool
    let barCount: Int
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isActive: Bool,
        barCount: Int = 5,
        color: Color = .DesignSystem.error
    ) {
        self.isActive = isActive
        self.barCount = barCount
        self.color = color
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : 1.0 / 60.0)) { timeline in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time * 5 + Double(index) * 0.5
                    let height = isActive
                        ? (sin(phase) * 0.3 + 0.5)
                        : 0.3

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3, height: max(4, height * 16))
                }
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Preview

#Preview("Voice Waveform Styles") {
    struct PreviewWrapper: View {
        @State private var isActive = true
        @State private var amplitude: CGFloat = 0.7

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Text("Voice Waveform")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    Toggle("Active", isOn: $isActive)
                        .padding(.horizontal)

                    Slider(value: $amplitude, in: 0...1) {
                        Text("Amplitude")
                    }
                    .padding(.horizontal)

                    // Circular style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Circular")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .padding(.horizontal)

                        GlassVoiceWaveform(
                            isActive: $isActive,
                            amplitude: amplitude,
                            style: .circular
                        )
                        .frame(height: 200)
                    }

                    // Linear style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Linear")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .padding(.horizontal)

                        GlassVoiceWaveform(
                            isActive: $isActive,
                            amplitude: amplitude,
                            style: .linear,
                            showMic: false
                        )
                        .frame(height: 80)
                    }

                    // Mirrored style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Mirrored")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .padding(.horizontal)

                        GlassVoiceWaveform(
                            isActive: $isActive,
                            amplitude: amplitude,
                            style: .mirrored,
                            showMic: false
                        )
                        .frame(height: 100)
                    }

                    // Wave style
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Wave")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .padding(.horizontal)

                        GlassVoiceWaveform(
                            isActive: $isActive,
                            amplitude: amplitude,
                            style: .wave,
                            showMic: false
                        )
                        .frame(height: 80)
                    }

                    // Compact
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Compact (Inline)")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .padding(.horizontal)

                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.DesignSystem.error)
                            GlassVoiceWaveformCompact(isActive: isActive)
                            Text("Listening...")
                                .font(.DesignSystem.bodyMedium)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}
