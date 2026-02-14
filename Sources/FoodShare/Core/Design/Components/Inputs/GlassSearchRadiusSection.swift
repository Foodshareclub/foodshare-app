//
//  GlassSearchRadiusSection.swift
//  Foodshare
//
//  Reusable search radius section with Liquid Glass design
//  Used in FilterSheet, EditProfileView, and SettingsView
//

import FoodShareDesignSystem
import OSLog
import SwiftUI

// MARK: - Glass Search Radius Section

/// A reusable search radius input section with:
/// - Large gradient display value (full mode) or compact inline row (compact mode)
/// - Slider with haptic feedback
/// - Range labels (min/max)
/// - Quick select pills (full mode only)
/// - Locale-aware unit handling (km/mi)
///
/// Example usage:
/// ```swift
/// // Full mode (for FilterSheet)
/// GlassSearchRadiusSection(
///     radiusLocalized: $radiusLocalized,
///     distanceUnit: .current,
///     onRadiusChange: { newRadiusKm in
///         await viewModel.updateSearchRadius(newRadiusKm)
///     }
/// )
///
/// // Compact mode (for Settings)
/// GlassSearchRadiusSection(
///     radiusLocalized: $radiusLocalized,
///     distanceUnit: .current,
///     style: .compact,
///     onRadiusChange: { newRadiusKm in
///         await viewModel.updateSearchRadius(newRadiusKm)
///     }
/// )
/// ```
struct GlassSearchRadiusSection: View {
    /// Display style for the search radius section
    enum Style {
        /// Full display with large value, slider, and quick select pills
        case full
        /// Compact inline display for settings rows
        case compact
    }

    /// Radius value in the user's locale unit (km or mi)
    @Binding var radiusLocalized: Double

    /// The distance unit to display (km or mi)
    let distanceUnit: DistanceUnit

    /// Display style (full or compact)
    let style: Style

    /// Callback when radius changes (receives value in kilometers)
    let onRadiusChange: ((Double) async -> Void)?

    /// Whether the slider is currently being dragged
    @State private var sliderIsActive = false

    /// Tolerance for quick select comparison
    private static let quickSelectTolerance = 0.1

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "GlassSearchRadiusSection")

    // MARK: - Initialization

    init(
        radiusLocalized: Binding<Double>,
        distanceUnit: DistanceUnit = .current,
        style: Style = .full,
        onRadiusChange: ((Double) async -> Void)? = nil,
    ) {
        self._radiusLocalized = radiusLocalized
        self.distanceUnit = distanceUnit
        self.style = style
        self.onRadiusChange = onRadiusChange
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .full:
            fullStyleBody
        case .compact:
            compactStyleBody
        }
    }

    // MARK: - Full Style Body

    private var fullStyleBody: some View {
        VStack(spacing: Spacing.md) {
            // Radius value display with pulsing animation
            radiusDisplayView

            // Slider with haptic feedback
            sliderSection

            // Quick select pills
            quickSelectPills
        }
    }

    // MARK: - Compact Style Body

    private var compactStyleBody: some View {
        VStack(spacing: Spacing.sm) {
            // Header row with icon, label, and value
            HStack(spacing: Spacing.md) {
                Image(systemName: "scope")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 28)

                Text("Search Radius")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                Text("\(radiusDisplayValue) \(distanceUnit.symbol)")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .contentTransition(.numericText())
                    .animation(ProMotionAnimation.smooth, value: radiusLocalized)
            }

            // Compact slider
            Slider(
                value: $radiusLocalized,
                in: distanceUnit.minSliderValue ... distanceUnit.maxSliderValue,
                step: distanceUnit.sliderStep,
                onEditingChanged: { isEditing in
                    sliderIsActive = isEditing
                    if isEditing {
                        HapticManager.soft()
                    } else {
                        let radiusInKm = distanceUnit.convertToKilometers(radiusLocalized)
                        logger
                            .info(
                                "Compact slider value changed: \(radiusLocalized) \(distanceUnit.symbol) -> \(radiusInKm)km",
                            )
                        if let onRadiusChange {
                            Task { @MainActor in
                                await onRadiusChange(radiusInKm)
                            }
                        }
                        HapticManager.medium()
                    }
                },
            )
            .tint(.DesignSystem.brandGreen)
            .accessibilityValue("\(radiusDisplayValue) \(distanceUnit.symbol)")
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search radius: \(radiusDisplayValue) \(distanceUnit.symbol)")
        .accessibilityHint("Adjust slider to change search radius")
    }

    // MARK: - Radius Display

    private var radiusDisplayView: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(radiusDisplayValue)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .contentTransition(.numericText())
                .animation(ProMotionAnimation.smooth, value: radiusLocalized)
                .scaleEffect(sliderIsActive ? 1.05 : 1.0)
                .animation(ProMotionAnimation.bouncy, value: sliderIsActive)

            Text(distanceUnit.symbol)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search radius: \(radiusDisplayValue) \(distanceUnit.symbol)")
    }

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(spacing: Spacing.xs) {
            Slider(
                value: $radiusLocalized,
                in: distanceUnit.minSliderValue ... distanceUnit.maxSliderValue,
                step: distanceUnit.sliderStep,
                onEditingChanged: { isEditing in
                    sliderIsActive = isEditing
                    if isEditing {
                        HapticManager.soft()
                    } else {
                        // When editing ends, persist the final value
                        let radiusInKm = distanceUnit.convertToKilometers(radiusLocalized)
                        logger
                            .info("Slider value changed: \(radiusLocalized) \(distanceUnit.symbol) -> \(radiusInKm)km")
                        if let onRadiusChange {
                            Task { @MainActor in
                                await onRadiusChange(radiusInKm)
                            }
                        }
                        HapticManager.medium()
                    }
                },
            )
            .tint(.DesignSystem.brandGreen)
            .accessibilityValue("\(radiusDisplayValue) \(distanceUnit.symbol)")

            // Range labels
            HStack {
                Text(distanceUnit.format(distanceUnit.minSliderValue))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
                    .accessibilityLabel("Minimum radius: \(distanceUnit.format(distanceUnit.minSliderValue))")

                Spacer()

                Text(distanceUnit.format(distanceUnit.maxSliderValue))
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textTertiary)
                    .accessibilityLabel("Maximum radius: \(distanceUnit.format(distanceUnit.maxSliderValue))")
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Quick Select Pills

    private var quickSelectPills: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(quickSelectValues, id: \.self) { value in
                Button {
                    withAnimation(ProMotionAnimation.smooth) {
                        radiusLocalized = value
                    }
                    HapticManager.light()
                    // Persist the quick select value
                    let radiusInKm = distanceUnit.convertToKilometers(value)
                    logger.info("Quick select: \(value) \(distanceUnit.symbol) -> \(radiusInKm)km")
                    if let onRadiusChange {
                        Task { @MainActor in
                            await onRadiusChange(radiusInKm)
                        }
                    }
                } label: {
                    Text(distanceUnit.format(value))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(isQuickSelectActive(value) ? .semibold : .regular)
                        .foregroundColor(
                            isQuickSelectActive(value) ? .white : .DesignSystem.text,
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(
                                    isQuickSelectActive(value)
                                        ? Color.DesignSystem.brandGreen
                                        : Color.clear,
                                )
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial),
                                ),
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isQuickSelectActive(value)
                                        ? Color.DesignSystem.brandGreen.opacity(0.5)
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        )
                        .shadow(
                            color: isQuickSelectActive(value)
                                ? Color.DesignSystem.brandGreen.opacity(0.3)
                                : .clear,
                            radius: 6,
                            y: 2,
                        )
                }
                .buttonStyle(ProMotionButtonStyle())
                .accessibilityLabel("Set radius to \(distanceUnit.format(value))")
                .accessibilityHint("Double tap to quickly set search radius")
                .accessibilityAddTraits(isQuickSelectActive(value) ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Helper Properties

    /// Display value for the radius (handles decimal display for miles)
    private var radiusDisplayValue: String {
        switch distanceUnit {
        case .kilometers:
            "\(Int(radiusLocalized.rounded()))"
        case .miles:
            // Show one decimal for miles if not a whole number
            if radiusLocalized.truncatingRemainder(dividingBy: 1) == 0 {
                "\(Int(radiusLocalized))"
            } else {
                String(format: "%.1f", radiusLocalized)
            }
        }
    }

    /// Quick select values based on locale
    private var quickSelectValues: [Double] {
        switch distanceUnit {
        case .kilometers:
            [50, 150, 400, 800]
        case .miles:
            [25, 100, 250, 500]
        }
    }

    /// Check if a quick select value is currently active
    private func isQuickSelectActive(_ value: Double) -> Bool {
        abs(radiusLocalized - value) < Self.quickSelectTolerance
    }

}

// MARK: - Preview

#Preview("Glass Search Radius Section") {
    struct PreviewWrapper: View {
        @State private var radiusKm: Double = 25
        @State private var radiusMi: Double = 15
        @State private var radiusCompact: Double = 127

        var body: some View {
            ScrollView {
                ZStack {
                    Color.DesignSystem.background.ignoresSafeArea()

                    VStack(spacing: Spacing.xl) {
                        Text("Search Radius Section")
                            .font(.DesignSystem.displayMedium)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        // Full style - Kilometers
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Full Style (Kilometers)")
                                .font(.DesignSystem.labelLarge)
                                .foregroundStyle(Color.DesignSystem.textSecondary)

                            GlassSearchRadiusSection(
                                radiusLocalized: $radiusKm,
                                distanceUnit: .kilometers,
                                style: .full,
                            )
                        }
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(.ultraThinMaterial),
                        )

                        // Full style - Miles
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Full Style (Miles)")
                                .font(.DesignSystem.labelLarge)
                                .foregroundStyle(Color.DesignSystem.textSecondary)

                            GlassSearchRadiusSection(
                                radiusLocalized: $radiusMi,
                                distanceUnit: .miles,
                                style: .full,
                            )
                        }
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(.ultraThinMaterial),
                        )

                        // Compact style (for Settings)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Compact Style (Settings)")
                                .font(.DesignSystem.labelLarge)
                                .foregroundStyle(Color.DesignSystem.textSecondary)

                            GlassSearchRadiusSection(
                                radiusLocalized: $radiusCompact,
                                distanceUnit: .miles,
                                style: .compact,
                            )
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(.ultraThinMaterial),
                            )
                        }
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(.ultraThinMaterial),
                        )
                    }
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}
