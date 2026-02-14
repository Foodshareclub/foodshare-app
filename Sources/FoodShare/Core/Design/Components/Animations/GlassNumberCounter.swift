//
//  GlassNumberCounter.swift
//  Foodshare
//
//  Liquid Glass v27 - Animated Number Counter
//  ProMotion 120Hz optimized number transitions with fluid interpolation
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Number Counter

/// A ProMotion-optimized animated number counter with fluid digit transitions
///
/// Supports multiple display formats and animation styles for use in
/// stat displays, like counts, message badges, and more.
///
/// Example usage:
/// ```swift
/// GlassNumberCounter(value: likeCount)
/// GlassNumberCounter(value: messageCount, format: .compact)
/// GlassNumberCounter(value: rating, format: .decimal(1), font: .DesignSystem.headlineLarge)
/// ```
struct GlassNumberCounter: View {
    let value: Double
    let format: NumberFormat
    let font: Font
    let color: Color
    let animationStyle: AnimationStyle

    @State private var displayValue: Double = 0
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    init(
        value: Int,
        format: NumberFormat = .integer,
        font: Font = .DesignSystem.bodyLarge,
        color: Color = .DesignSystem.textPrimary,
        animationStyle: AnimationStyle = .smooth
    ) {
        self.value = Double(value)
        self.format = format
        self.font = font
        self.color = color
        self.animationStyle = animationStyle
    }

    init(
        value: Double,
        format: NumberFormat = .decimal(1),
        font: Font = .DesignSystem.bodyLarge,
        color: Color = .DesignSystem.textPrimary,
        animationStyle: AnimationStyle = .smooth
    ) {
        self.value = value
        self.format = format
        self.font = font
        self.color = color
        self.animationStyle = animationStyle
    }

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            // Static display for reduced motion
            Text(formattedValue(value))
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.identity)
                .accessibilityLabel(accessibilityText)
        } else {
            // Animated counter
            Text(formattedValue(displayValue))
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: displayValue > value))
                .monospacedDigit()
                .accessibilityLabel(accessibilityText)
                .onAppear {
                    displayValue = value
                }
                .onChange(of: value) { oldValue, newValue in
                    animateChange(from: oldValue, to: newValue)
                }
        }
    }

    // MARK: - Animation

    private func animateChange(from oldValue: Double, to newValue: Double) {
        withAnimation(animationStyle.animation) {
            displayValue = newValue
        }
    }

    // MARK: - Formatting

    private func formattedValue(_ number: Double) -> String {
        switch format {
        case .integer:
            return String(Int(number))

        case .decimal(let places):
            return String(format: "%.\(places)f", number)

        case .compact:
            return compactFormat(number)

        case .percentage:
            return String(format: "%.0f%%", number * 100)

        case .currency(let symbol):
            return "\(symbol)\(String(format: "%.2f", number))"

        case .custom(let formatter):
            return formatter(number)
        }
    }

    private func compactFormat(_ number: Double) -> String {
        let absNumber = abs(number)
        let sign = number < 0 ? "-" : ""

        switch absNumber {
        case 0..<1000:
            return "\(sign)\(Int(absNumber))"
        case 1000..<1_000_000:
            let value = absNumber / 1000
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(sign)\(Int(value))K"
                : "\(sign)\(String(format: "%.1f", value))K"
        case 1_000_000..<1_000_000_000:
            let value = absNumber / 1_000_000
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(sign)\(Int(value))M"
                : "\(sign)\(String(format: "%.1f", value))M"
        default:
            let value = absNumber / 1_000_000_000
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(sign)\(Int(value))B"
                : "\(sign)\(String(format: "%.1f", value))B"
        }
    }

    private var accessibilityText: String {
        switch format {
        case .integer:
            return "\(Int(value))"
        case .decimal(let places):
            return String(format: "%.\(places)f", value)
        case .compact:
            return "\(Int(value))"
        case .percentage:
            return "\(Int(value * 100)) percent"
        case .currency(let symbol):
            return "\(symbol)\(String(format: "%.2f", value))"
        case .custom:
            return formattedValue(value)
        }
    }
}

// MARK: - Number Format

extension GlassNumberCounter {
    /// Number display format options
    enum NumberFormat {
        /// Integer format (no decimals)
        case integer

        /// Decimal format with specified places
        case decimal(Int)

        /// Compact format (1K, 1.5M, etc.)
        case compact

        /// Percentage format (0-1 displayed as 0%-100%)
        case percentage

        /// Currency format with symbol
        case currency(String)

        /// Custom formatter
        case custom((Double) -> String)
    }
}

// MARK: - Animation Style

extension GlassNumberCounter {
    /// Animation style presets for number transitions
    enum AnimationStyle {
        /// Instant response (~150ms) - for micro-interactions
        case instant

        /// Quick spring (~200ms) - for small UI changes
        case quick

        /// Smooth spring (~300ms) - default for most counters
        case smooth

        /// Bouncy spring (~500ms) - for playful celebrations
        case bouncy

        /// Counter-optimized spring
        case counter

        var animation: Animation {
            switch self {
            case .instant:
                return .interpolatingSpring(stiffness: 400, damping: 30)
            case .quick:
                return .interpolatingSpring(stiffness: 300, damping: 25)
            case .smooth:
                return .interpolatingSpring(stiffness: 200, damping: 22)
            case .bouncy:
                return .interpolatingSpring(stiffness: 250, damping: 15)
            case .counter:
                return .interpolatingSpring(stiffness: 280, damping: 25)
            }
        }
    }
}

// MARK: - TimelineView Counter (Advanced)

/// Advanced frame-perfect counter using TimelineView for maximum smoothness
/// Use for prominent stat displays that need perfect 120fps interpolation
struct ProMotionNumberCounter: View {
    let targetValue: Double
    let duration: Double
    let format: GlassNumberCounter.NumberFormat
    let font: Font
    let color: Color

    @State private var startValue: Double = 0
    @State private var currentValue: Double = 0
    @State private var animationStartTime: Date?
    @State private var isAnimating = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        value: Double,
        duration: Double = 0.5,
        format: GlassNumberCounter.NumberFormat = .integer,
        font: Font = .DesignSystem.bodyLarge,
        color: Color = .DesignSystem.textPrimary
    ) {
        self.targetValue = value
        self.duration = duration
        self.format = format
        self.font = font
        self.color = color
    }

    init(
        value: Int,
        duration: Double = 0.5,
        format: GlassNumberCounter.NumberFormat = .integer,
        font: Font = .DesignSystem.bodyLarge,
        color: Color = .DesignSystem.textPrimary
    ) {
        self.targetValue = Double(value)
        self.duration = duration
        self.format = format
        self.font = font
        self.color = color
    }

    var body: some View {
        if reduceMotion {
            Text(formattedValue(targetValue))
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: !isAnimating)) { timeline in
                let displayValue = calculateValue(at: timeline.date)

                Text(formattedValue(displayValue))
                    .font(font)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            .onAppear {
                currentValue = targetValue
            }
            .onChange(of: targetValue) { oldValue, newValue in
                startAnimation(from: currentValue, to: newValue)
            }
        }
    }

    private func calculateValue(at date: Date) -> Double {
        guard let startTime = animationStartTime else {
            return targetValue
        }

        let elapsed = date.timeIntervalSince(startTime)
        let progress = min(elapsed / duration, 1.0)

        // Ease-out cubic for smooth deceleration
        let easedProgress = 1.0 - pow(1.0 - progress, 3)

        let value = startValue + (targetValue - startValue) * easedProgress

        if progress >= 1.0 {
            isAnimating = false
            currentValue = targetValue
        }

        return value
    }

    private func startAnimation(from: Double, to: Double) {
        startValue = from
        animationStartTime = Date()
        isAnimating = true
    }

    private func formattedValue(_ number: Double) -> String {
        switch format {
        case .integer:
            return String(Int(number))
        case .decimal(let places):
            return String(format: "%.\(places)f", number)
        case .compact:
            return compactFormat(number)
        case .percentage:
            return String(format: "%.0f%%", number * 100)
        case .currency(let symbol):
            return "\(symbol)\(String(format: "%.2f", number))"
        case .custom(let formatter):
            return formatter(number)
        }
    }

    private func compactFormat(_ number: Double) -> String {
        let absNumber = abs(number)
        let sign = number < 0 ? "-" : ""

        switch absNumber {
        case 0..<1000:
            return "\(sign)\(Int(absNumber))"
        case 1000..<1_000_000:
            let value = absNumber / 1000
            return "\(sign)\(String(format: "%.1f", value))K"
        default:
            let value = absNumber / 1_000_000
            return "\(sign)\(String(format: "%.1f", value))M"
        }
    }
}

// MARK: - Glass Stat Counter (Styled Wrapper)

/// A styled stat counter with glass aesthetics
/// Use for profile stats, dashboard metrics, etc.
struct GlassStatCounter: View {
    let value: Int
    let label: String
    let icon: String?
    let color: Color
    let format: GlassNumberCounter.NumberFormat

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        value: Int,
        label: String,
        icon: String? = nil,
        color: Color = .DesignSystem.brandGreen,
        format: GlassNumberCounter.NumberFormat = .compact
    ) {
        self.value = value
        self.label = label
        self.icon = icon
        self.color = color
        self.format = format
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                }

                GlassNumberCounter(
                    value: hasAppeared ? value : 0,
                    format: format,
                    font: .DesignSystem.headlineMedium,
                    color: .DesignSystem.textPrimary,
                    animationStyle: .counter
                )
            }

            Text(label)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 22).delay(0.2)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Glass Number Counter") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Glass Number Counter")
                .font(.DesignSystem.displayMedium)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            // Basic integer counter
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Integer Counter")
                    .font(.DesignSystem.headlineSmall)

                HStack(spacing: Spacing.lg) {
                    GlassNumberCounter(value: 42)
                    GlassNumberCounter(value: 1234)
                    GlassNumberCounter(value: 99999)
                }
            }

            // Compact format
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Compact Format")
                    .font(.DesignSystem.headlineSmall)

                HStack(spacing: Spacing.lg) {
                    GlassNumberCounter(value: 1500, format: .compact)
                    GlassNumberCounter(value: 25000, format: .compact)
                    GlassNumberCounter(value: 1500000, format: .compact)
                }
            }

            // Decimal format
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Decimal Format")
                    .font(.DesignSystem.headlineSmall)

                HStack(spacing: Spacing.lg) {
                    GlassNumberCounter(value: 4.5, format: .decimal(1))
                    GlassNumberCounter(value: 3.14159, format: .decimal(2))
                }
            }

            // Styled stat counters
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Stat Counters")
                    .font(.DesignSystem.headlineSmall)

                HStack(spacing: Spacing.md) {
                    GlassStatCounter(value: 1234, label: "Followers", icon: "person.2.fill")
                    GlassStatCounter(value: 567, label: "Posts", icon: "square.stack.fill", color: .DesignSystem.brandPink)
                    GlassStatCounter(value: 89, label: "Likes", icon: "heart.fill", color: .DesignSystem.error)
                }
            }

            // ProMotion counter
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("ProMotion Counter (120Hz)")
                    .font(.DesignSystem.headlineSmall)

                ProMotionNumberCounter(
                    value: 12345,
                    duration: 1.0,
                    font: .DesignSystem.displayLarge,
                    color: .DesignSystem.brandGreen
                )
            }
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}
