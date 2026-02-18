//
//  GlassSlider.swift
//  Foodshare
//
//  Liquid Glass v26 Slider Component with ProMotion-optimized animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Slider

struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let label: String?
    let showValue: Bool
    let valueFormatter: (Double) -> String
    let icon: String?
    let accentColor: Color

    @State private var isDragging = false

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        label: String? = nil,
        showValue: Bool = true,
        icon: String? = nil,
        accentColor: Color = .DesignSystem.brandGreen,
        valueFormatter: @escaping (Double) -> String = { "\(Int($0))" },
    ) {
        _value = value
        self.range = range
        self.step = step
        self.label = label
        self.showValue = showValue
        self.icon = icon
        self.accentColor = accentColor
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Label row
            if label != nil || showValue {
                HStack {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accentColor)
                    }

                    if let label {
                        Text(label)
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.text)
                    }

                    Spacer()

                    if showValue {
                        Text(valueFormatter(value))
                            .font(.DesignSystem.labelLarge)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            #if !SKIP
                            .contentTransition(.numericText())
                            #endif
                            .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: value)
                    }
                }
            }

            // Slider track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        #if !SKIP
                        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .background(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1),
                        )

                    // Fill track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: max(0.0, fillWidth(for: geometry.size.width)))
                        .shadow(color: accentColor.opacity(isDragging ? 0.5 : 0.3), radius: isDragging ? 8 : 4, y: 0)

                    // Thumb
                    Circle()
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom,
                                    ),
                                ),
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isDragging
                                        ? accentColor.opacity(0.8)
                                        : Color.white.opacity(0.3),
                                    lineWidth: isDragging ? 2 : 1,
                                ),
                        )
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                        .shadow(color: accentColor.opacity(isDragging ? 0.4 : 0), radius: 12, y: 0)
                        .scaleEffect(isDragging ? 1.15 : 1.0)
                        .offset(x: thumbOffset(for: geometry.size.width))
                        .animation(Animation.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
                }
                .frame(height: trackHeight)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            updateValue(at: gesture.location.x, width: geometry.size.width)
                            HapticManager.selection()
                        }
                        .onEnded { _ in
                            isDragging = false
                            HapticManager.light()
                        },
                )
            }
            .frame(height: trackHeight)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.white.opacity(0.06))
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDragging ? 0.2 : 0.12),
                            Color.white.opacity(isDragging ? 0.1 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .animation(Animation.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
    }

    // MARK: - Layout Properties

    private var trackHeight: CGFloat { 28 }
    private var thumbSize: CGFloat { 24 }

    // MARK: - Calculations

    private func normalizedValue() -> Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func fillWidth(for totalWidth: CGFloat) -> CGFloat {
        let progress = normalizedValue()
        return (totalWidth - thumbSize) * progress + thumbSize / 2
    }

    private func thumbOffset(for totalWidth: CGFloat) -> CGFloat {
        let progress = normalizedValue()
        return (totalWidth - thumbSize) * progress
    }

    private func updateValue(at locationX: CGFloat, width: CGFloat) {
        let clampedX = min(max(0.0, locationX), width)
        let progress = clampedX / width
        var newValue = range.lowerBound + (range.upperBound - range.lowerBound) * progress

        // Apply step if provided
        if let step {
            newValue = (newValue / step).rounded() * step
        }

        // Clamp to range
        value = min(max(range.lowerBound, newValue), range.upperBound)
    }
}

// MARK: - Radius Slider Variant

struct GlassRadiusSlider: View {
    @Binding var radiusKm: Double
    let maxRadius: Double

    init(radiusKm: Binding<Double>, maxRadius: Double = 50) {
        _radiusKm = radiusKm
        self.maxRadius = maxRadius
    }

    var body: some View {
        GlassSlider(
            value: $radiusKm,
            in: 1 ... maxRadius,
            step: 1,
            label: "Search Radius",
            icon: "location.circle.fill",
            accentColor: Color.DesignSystem.brandBlue,
            valueFormatter: { "\(Int($0)) km" },
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassSlider(
                value: .constant(50),
                in: 0 ... 100,
                label: "Volume",
                icon: "speaker.wave.3.fill",
                accentColor: .DesignSystem.brandGreen,
            )

            GlassSlider(
                value: .constant(25),
                in: 0 ... 50,
                step: 5,
                label: "Distance",
                icon: "location.fill",
                accentColor: Color.DesignSystem.brandBlue,
                valueFormatter: { "\(Int($0)) km" },
            )

            GlassRadiusSlider(radiusKm: .constant(10))

            GlassSlider(
                value: .constant(0.7),
                in: 0 ... 1,
                label: "Brightness",
                icon: "sun.max.fill",
                accentColor: .DesignSystem.accentYellow,
                valueFormatter: { "\(Int($0 * 100))%" },
            )
        }
        .padding()
    }
}

#endif
