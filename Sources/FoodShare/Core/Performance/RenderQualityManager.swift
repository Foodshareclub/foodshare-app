//
//  RenderQualityManager.swift
//  FoodShare
//
//  Adaptive rendering quality management based on device capabilities.
//  Dynamically adjusts Liquid Glass effects based on GPU performance, thermal state,
//  and frame rate to maintain 60+ FPS on all devices.
//
//  Features:
//  - Device capability detection (GPU, RAM, screen refresh rate)
//  - Thermal state monitoring with automatic quality reduction
//  - Frame rate based auto-adjustment using CADisplayLink
//  - Quality presets for Liquid Glass effects (ultra, high, medium, low)
//  - SwiftUI environment integration
//  - Memory pressure integration
//
//  Usage:
//  ```swift
//  @Environment(\.renderQuality) private var quality
//
//  view
//      .blur(radius: quality.blurIntensity)
//      .shadow(radius: quality.shadowRadius)
//  ```
//


#if !SKIP
import Combine
import Foundation
import OSLog
#if !SKIP
import QuartzCore
#endif
import SwiftUI
#if !SKIP
import UIKit
#endif

// MARK: - Render Quality Level

/// Quality levels for adaptive rendering
public enum RenderQuality: Int, Comparable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case ultra = 3

    public static func < (lhs: RenderQuality, rhs: RenderQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .ultra: "Ultra"
        }
    }

    /// Blur intensity for glass effects
    public var blurIntensity: CGFloat {
        switch self {
        case .ultra: 20
        case .high: 15
        case .medium: 10
        case .low: 5
        }
    }

    /// Shadow radius for cards and overlays
    public var shadowRadius: CGFloat {
        switch self {
        case .ultra: 16
        case .high: 12
        case .medium: 8
        case .low: 4
        }
    }

    /// Maximum number of shadow layers
    public var shadowLayers: Int {
        switch self {
        case .ultra: 3
        case .high: 2
        case .medium: 1
        case .low: 1
        }
    }

    /// Animation complexity level
    public var animationComplexity: AnimationComplexity {
        switch self {
        case .ultra: .full
        case .high: .full
        case .medium: .reduced
        case .low: .minimal
        }
    }

    /// Whether to enable glass material effects
    public var enableGlassMaterial: Bool {
        self >= .medium
    }

    /// Whether to enable GPU rasterization for complex views
    public var useGPURasterization: Bool {
        self >= .high
    }

    /// Whether to enable complex gradients
    public var enableComplexGradients: Bool {
        self >= .medium
    }

    /// Whether to enable shimmer effects
    public var enableShimmerEffects: Bool {
        self >= .medium
    }

    /// Maximum blur radius to prevent performance issues
    public var maxBlurRadius: CGFloat {
        switch self {
        case .ultra: 30
        case .high: 20
        case .medium: 12
        case .low: 6
        }
    }

    /// Corner radius for glass elements
    public var cornerRadius: CGFloat {
        switch self {
        case .ultra: 24
        case .high: 20
        case .medium: 16
        case .low: 12
        }
    }

    /// Whether to enable parallax effects
    public var enableParallax: Bool {
        self >= .high
    }
}

// MARK: - Animation Complexity

public enum AnimationComplexity: String, Sendable {
    case minimal // Only essential animations
    case reduced // Standard animations at lower frame rate
    case full // All animations at full quality

    public var shouldReduceMotion: Bool {
        self != .full
    }
}

// MARK: - Device Capabilities

public struct DeviceCapabilities: Sendable {
    public let deviceModel: String
    public let totalMemoryGB: Double
    public let cpuCount: Int
    public let gpuFamily: GPUFamily
    public let supportsProMotion: Bool
    public let maxFrameRate: Int
    public let screenScale: CGFloat

    public enum GPUFamily: String, Sendable {
        case apple1 // A7
        case apple2 // A8
        case apple3 // A9/A10
        case apple4 // A11
        case apple5 // A12/A13
        case apple6 // A14
        case apple7 // A15
        case apple8 // A16
        case apple9 // A17 Pro
        case unknown

        var recommendedQuality: RenderQuality {
            switch self {
            case .apple9, .apple8: .ultra
            case .apple7, .apple6: .high
            case .apple5, .apple4: .medium
            default: .low
            }
        }
    }

    /// Recommended quality based on device capabilities
    public var recommendedQuality: RenderQuality {
        // ProMotion devices can handle ultra quality
        if supportsProMotion, totalMemoryGB >= 6 {
            return .ultra
        }

        // Modern devices with 4GB+ RAM
        if totalMemoryGB >= 4, gpuFamily.recommendedQuality >= .high {
            return .high
        }

        // Mid-range devices
        if totalMemoryGB >= 3, gpuFamily.recommendedQuality >= .medium {
            return .medium
        }

        // Older devices
        return .low
    }
}

// MARK: - Quality Settings

public struct QualitySettings: Sendable {
    public let quality: RenderQuality
    public let thermalState: ProcessInfo.ThermalState
    public let memoryPressure: MemoryPressureLevel
    public let averageFPS: Double
    public let isLowPowerModeEnabled: Bool

    public var effectiveQuality: RenderQuality {
        var effective = quality

        // Reduce quality based on thermal state
        if thermalState == .serious {
            effective = min(effective, .medium)
        } else if thermalState == .critical {
            effective = .low
        }

        // Reduce quality based on memory pressure
        if memoryPressure >= .critical {
            effective = min(effective, .low)
        } else if memoryPressure >= .warning {
            effective = min(effective, .medium)
        }

        // Reduce quality if frame rate is low
        if averageFPS < 30 {
            effective = min(effective, .low)
        } else if averageFPS < 45 {
            effective = min(effective, .medium)
        }

        // Reduce quality in low power mode
        if isLowPowerModeEnabled {
            effective = min(effective, .medium)
        }

        return effective
    }

    public var shouldReduceComplexity: Bool {
        thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue || memoryPressure >= .critical || averageFPS < 30
    }
}

// MARK: - Render Quality Manager

@MainActor
@Observable
public final class RenderQualityManager {

    // MARK: - Singleton

    public static let shared = RenderQualityManager()

    // MARK: - Published Properties

    /// Current render quality level
    public private(set) var currentQuality: RenderQuality

    /// Device capabilities
    public private(set) var deviceCapabilities: DeviceCapabilities

    /// Current quality settings including environmental factors
    public private(set) var settings: QualitySettings

    /// Whether auto-adjustment is enabled
    public private(set) var isAutoAdjustEnabled = true

    /// Current thermal state
    public private(set) var thermalState: ProcessInfo.ThermalState = .nominal

    /// Current frame rate from monitor
    public private(set) var currentFPS: Double = 60

    /// Average frame rate over monitoring period
    public private(set) var averageFPS: Double = 60

    /// Number of quality reductions due to performance
    public private(set) var performanceAdjustmentCount = 0

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// Target minimum FPS before reducing quality
        public var targetMinFPS: Double = 50

        /// Target FPS for ProMotion devices
        public var targetProMotionFPS: Double = 100

        /// Monitoring interval for frame rate
        public var monitoringInterval: TimeInterval = 1.0

        /// Number of consecutive low FPS readings before reducing quality
        public var lowFPSThreshold = 3

        /// Time to wait before increasing quality after reduction (seconds)
        public var qualityRecoveryDelay: TimeInterval = 10.0

        /// Enable automatic quality adjustment
        public var enableAutoAdjustment = true

        public static let `default` = Configuration()
    }

    public var configuration = Configuration.default

    // MARK: - Private Properties

    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0
    private var accumulatedTime: CFTimeInterval = 0
    private var fpsHistory: [Double] = []
    private let historySize = 60
    private var lowFPSCount = 0
    private var lastQualityReduction: Date?
    nonisolated(unsafe) private var thermalStateObserver: NSObjectProtocol?
    nonisolated(unsafe) private var lowPowerModeObserver: NSObjectProtocol?

    // Logger
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "RenderQualityManager")

    // MARK: - Initialization

    private init() {
        let caps = Self.detectDeviceCapabilities()
        let quality = caps.recommendedQuality
        deviceCapabilities = caps
        currentQuality = quality

        settings = QualitySettings(
            quality: quality,
            thermalState: .nominal,
            memoryPressure: .normal,
            averageFPS: 60,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
        )

        setupObservers()

        logger.info("""
        [RenderQuality] Initialized
        - Device: \(self.deviceCapabilities.deviceModel)
        - GPU: \(self.deviceCapabilities.gpuFamily.rawValue)
        - Memory: \(String(format: "%.1f", self.deviceCapabilities.totalMemoryGB))GB
        - ProMotion: \(self.deviceCapabilities.supportsProMotion)
        - Recommended Quality: \(self.currentQuality.description)
        """)
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = lowPowerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Start monitoring frame rate and thermal state
    public func startMonitoring() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: Float(deviceCapabilities.maxFrameRate),
            preferred: Float(deviceCapabilities.maxFrameRate),
        )
        displayLink?.add(to: .main, forMode: .common)

        logger.info("[RenderQuality] Started monitoring")
    }

    /// Stop monitoring frame rate
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Manually set quality level (disables auto-adjustment)
    public func setQuality(_ quality: RenderQuality, autoAdjust: Bool = false) {
        currentQuality = quality
        isAutoAdjustEnabled = autoAdjust
        updateSettings()

        logger.info("[RenderQuality] Manually set to \(quality.description), auto-adjust: \(autoAdjust)")

        NotificationCenter.default.post(name: .renderQualityChanged, object: nil, userInfo: ["quality": quality])
    }

    /// Reset to recommended quality for device
    public func resetToRecommended() {
        currentQuality = deviceCapabilities.recommendedQuality
        isAutoAdjustEnabled = true
        performanceAdjustmentCount = 0
        lastQualityReduction = nil
        lowFPSCount = 0
        updateSettings()

        logger.info("[RenderQuality] Reset to recommended: \(self.currentQuality.description)")
    }

    /// Enable or disable auto-adjustment
    public func setAutoAdjustEnabled(_ enabled: Bool) {
        isAutoAdjustEnabled = enabled

        logger.info("[RenderQuality] Auto-adjustment \(enabled ? "enabled" : "disabled")")
    }

    /// Force quality reduction (e.g., during heavy operations)
    public func temporaryReduceQuality(duration: TimeInterval = 5.0) {
        let originalQuality = currentQuality
        currentQuality = max(.low, RenderQuality(rawValue: currentQuality.rawValue - 1) ?? .low)
        updateSettings()

        Task {
            try? await Task.sleep(for: .seconds(duration))
            if currentQuality.rawValue < originalQuality.rawValue {
                currentQuality = originalQuality
                updateSettings()
            }
        }
    }

    /// Get quality metrics for reporting
    public func getMetrics() -> QualityMetrics {
        QualityMetrics(
            currentQuality: currentQuality,
            effectiveQuality: settings.effectiveQuality,
            deviceCapabilities: deviceCapabilities,
            currentFPS: currentFPS,
            averageFPS: averageFPS,
            thermalState: thermalState,
            memoryPressure: MemoryPressureManager.shared.currentLevel,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            adjustmentCount: performanceAdjustmentCount,
        )
    }

    // MARK: - Display Link Handler

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        let currentTimestamp = displayLink.timestamp

        if lastTimestamp == 0 {
            lastTimestamp = currentTimestamp
            return
        }

        let deltaTime = currentTimestamp - lastTimestamp
        lastTimestamp = currentTimestamp

        frameCount += 1
        accumulatedTime += deltaTime

        // Calculate FPS every monitoring interval
        if accumulatedTime >= configuration.monitoringInterval {
            currentFPS = Double(frameCount) / accumulatedTime

            // Update history
            fpsHistory.append(currentFPS)
            if fpsHistory.count > historySize {
                fpsHistory.removeFirst()
            }

            // Calculate average
            averageFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)

            // Auto-adjust quality if enabled
            if isAutoAdjustEnabled, configuration.enableAutoAdjustment {
                autoAdjustQuality()
            }

            // Update settings
            updateSettings()

            // Reset for next interval
            frameCount = 0
            accumulatedTime = 0
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Thermal state observer
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }

        // Low power mode observer
        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePowerStateChange()
            }
        }
    }

    private func handleThermalStateChange() {
        thermalState = ProcessInfo.processInfo.thermalState
        updateSettings()

        logger.info("[RenderQuality] Thermal state changed to \(self.thermalState.rawValue)")

        // Automatically reduce quality on thermal pressure
        if thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue, isAutoAdjustEnabled {
            reduceQuality(reason: "thermal_pressure")
        }

        NotificationCenter.default.post(
            name: .thermalStateChanged,
            object: nil,
            userInfo: ["state": thermalState.rawValue],
        )
    }

    private func handlePowerStateChange() {
        updateSettings()

        logger.info("[RenderQuality] Low power mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
    }

    private func autoAdjustQuality() {
        let targetFPS = deviceCapabilities.supportsProMotion
            ? configuration.targetProMotionFPS
            : configuration.targetMinFPS

        // Check if FPS is consistently low
        if averageFPS < targetFPS {
            lowFPSCount += 1

            if lowFPSCount >= configuration.lowFPSThreshold {
                reduceQuality(reason: "low_fps")
                lowFPSCount = 0
            }
        } else {
            lowFPSCount = 0

            // Try to increase quality if performance is good
            if averageFPS > targetFPS + 10, canIncreaseQuality() {
                increaseQuality()
            }
        }
    }

    private func reduceQuality(reason: String) {
        guard currentQuality > .low else { return }

        let newQuality = RenderQuality(rawValue: currentQuality.rawValue - 1) ?? .low
        currentQuality = newQuality
        lastQualityReduction = Date()
        performanceAdjustmentCount += 1

        updateSettings()

        logger.warning(
            "[RenderQuality] Reduced to \(self.currentQuality.description) (reason: \(reason), FPS: \(String(format: "%.1f", self.averageFPS)))",
        )

        NotificationCenter.default.post(
            name: .renderQualityReduced,
            object: nil,
            userInfo: ["quality": currentQuality, "reason": reason],
        )

        logger.debug("[RenderQuality] Quality reduction metric: \(reason), FPS: \(String(format: "%.1f", self.averageFPS))")
    }

    private func increaseQuality() {
        guard currentQuality < deviceCapabilities.recommendedQuality else { return }

        let newQuality = RenderQuality(rawValue: currentQuality.rawValue + 1) ?? currentQuality
        currentQuality = newQuality

        updateSettings()

        logger.info(
            "[RenderQuality] Increased to \(self.currentQuality.description) (FPS: \(String(format: "%.1f", self.averageFPS)))",
        )

        NotificationCenter.default.post(
            name: .renderQualityIncreased,
            object: nil,
            userInfo: ["quality": currentQuality],
        )
    }

    private func canIncreaseQuality() -> Bool {
        // Don't increase if we recently reduced
        if let lastReduction = lastQualityReduction {
            return Date().timeIntervalSince(lastReduction) > configuration.qualityRecoveryDelay
        }

        // Don't increase under thermal pressure
        if thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            return false
        }

        // Don't increase under memory pressure
        if MemoryPressureManager.shared.currentLevel >= .warning {
            return false
        }

        return true
    }

    private func updateSettings() {
        settings = QualitySettings(
            quality: currentQuality,
            thermalState: thermalState,
            memoryPressure: MemoryPressureManager.shared.currentLevel,
            averageFPS: averageFPS,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
        )
    }

    // MARK: - Device Detection

    private static func detectDeviceCapabilities() -> DeviceCapabilities {
        let processInfo = ProcessInfo.processInfo
        let device = UIDevice.current
        let screen = UIScreen.main

        // Memory
        let totalMemoryBytes = processInfo.physicalMemory
        let totalMemoryGB = Double(totalMemoryBytes) / 1_073_741_824 // 1024^3

        // CPU
        let cpuCount = processInfo.processorCount

        // GPU (approximate based on iOS version and device)
        let gpuFamily = detectGPUFamily()

        // Screen
        let maxFrameRate = screen.maximumFramesPerSecond
        let supportsProMotion = maxFrameRate >= 120
        let screenScale = screen.scale

        // Device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return DeviceCapabilities(
            deviceModel: identifier,
            totalMemoryGB: totalMemoryGB,
            cpuCount: cpuCount,
            gpuFamily: gpuFamily,
            supportsProMotion: supportsProMotion,
            maxFrameRate: maxFrameRate,
            screenScale: screenScale,
        )
    }

    private static func detectGPUFamily() -> DeviceCapabilities.GPUFamily {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // iPhone models mapped to GPU families
        // This is approximate - actual GPU family would require Metal feature set query
        if identifier.contains("iPhone16") || identifier.contains("iPhone15,3") {
            return .apple9 // A17 Pro (iPhone 15 Pro)
        } else if identifier.contains("iPhone15") || identifier.contains("iPhone14") {
            return .apple8 // A16 (iPhone 14/15)
        } else if identifier.contains("iPhone14") {
            return .apple7 // A15 (iPhone 13)
        } else if identifier.contains("iPhone13") {
            return .apple6 // A14 (iPhone 12)
        } else if identifier.contains("iPhone12") || identifier.contains("iPhone11") {
            return .apple5 // A13/A12 (iPhone 11/XS)
        } else if identifier.contains("iPhone10") {
            return .apple4 // A11 (iPhone X/8)
        } else if identifier.contains("iPhone9") {
            return .apple3 // A10 (iPhone 7)
        }

        return .unknown
    }
}

// MARK: - Quality Metrics

public struct QualityMetrics: Sendable {
    public let currentQuality: RenderQuality
    public let effectiveQuality: RenderQuality
    public let deviceCapabilities: DeviceCapabilities
    public let currentFPS: Double
    public let averageFPS: Double
    public let thermalState: ProcessInfo.ThermalState
    public let memoryPressure: MemoryPressureLevel
    public let isLowPowerMode: Bool
    public let adjustmentCount: Int

    public var isHealthy: Bool {
        effectiveQuality >= .medium && averageFPS >= 50 && thermalState.rawValue <= ProcessInfo.ThermalState.nominal.rawValue
    }

    public var formattedFPS: String {
        String(format: "%.1f", averageFPS)
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let renderQualityChanged = Notification.Name("renderQualityChanged")
    public static let renderQualityReduced = Notification.Name("renderQualityReduced")
    public static let renderQualityIncreased = Notification.Name("renderQualityIncreased")
    public static let thermalStateChanged = Notification.Name("thermalStateChanged")
}

extension EnvironmentValues {
    // Current effective render quality level
    @Entry public var renderQuality: RenderQuality = MainActor.assumeIsolated {
        RenderQualityManager.shared.settings.effectiveQuality
    }

    // Render quality manager instance
    @Entry public var renderQualityManager: RenderQualityManager = MainActor.assumeIsolated {
        RenderQualityManager.shared
    }
}

// MARK: - View Modifier

public struct RenderQualityAwareModifier: ViewModifier {
    @State private var manager = RenderQualityManager.shared

    public func body(content: Content) -> some View {
        content
            .environment(\.renderQuality, manager.settings.effectiveQuality)
            .environment(\.renderQualityManager, manager)
    }
}

extension View {
    /// Makes the view aware of render quality changes
    public func renderQualityAware() -> some View {
        modifier(RenderQualityAwareModifier())
    }
}

// MARK: - Adaptive Glass Modifiers

extension View {
    /// Apply glass effect with adaptive quality
    /// Automatically adjusts blur and shadow based on current render quality
    func adaptiveGlassEffect(
        cornerRadius: CGFloat = Spacing.radiusLG,
        borderWidth: CGFloat = 1,
    ) -> some View {
        modifier(AdaptiveGlassEffectModifier(
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
        ))
    }

    /// Apply shadow with adaptive quality
    public func adaptiveShadow(
        color: Color = .black,
        intensity: Double = 1.0,
    ) -> some View {
        modifier(AdaptiveShadowModifier(
            color: color,
            intensity: intensity,
        ))
    }

    /// Apply blur with adaptive quality
    public func adaptiveBlur(radius: CGFloat) -> some View {
        modifier(AdaptiveBlurModifier(targetRadius: radius))
    }
}

// MARK: - Adaptive Modifiers Implementation

private struct AdaptiveGlassEffectModifier: ViewModifier {
    @Environment(\.renderQuality) private var quality
    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        if quality.enableGlassMaterial {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            #if !SKIP
                            .fill(.ultraThinMaterial)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif

                        if quality.enableComplexGradients {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.DesignSystem.glassHighlight,
                                            Color.DesignSystem.glassBorder,
                                            Color.clear,
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                    lineWidth: borderWidth,
                                )
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: borderWidth)
                        }
                    },
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: Color.black.opacity(0.1), radius: quality.shadowRadius, y: quality.shadowRadius / 2)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.DesignSystem.glassBackground.opacity(0.8))
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: borderWidth),
                )
        }
    }
}

private struct AdaptiveShadowModifier: ViewModifier {
    @Environment(\.renderQuality) private var quality
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        let shadowColor = color.opacity(0.15 * intensity)

        Group {
            if quality.shadowLayers >= 2 {
                content
                    .shadow(color: shadowColor, radius: quality.shadowRadius, y: quality.shadowRadius / 2)
                    .shadow(
                        color: shadowColor.opacity(0.5),
                        radius: quality.shadowRadius * 0.5,
                        y: quality.shadowRadius / 4,
                    )
            } else {
                content
                    .shadow(color: shadowColor, radius: quality.shadowRadius, y: quality.shadowRadius / 2)
            }
        }
    }
}

private struct AdaptiveBlurModifier: ViewModifier {
    @Environment(\.renderQuality) private var quality
    let targetRadius: CGFloat

    func body(content: Content) -> some View {
        let effectiveRadius = min(targetRadius, quality.maxBlurRadius)

        if quality >= .medium {
            content.blur(radius: effectiveRadius)
        } else if quality == .low, targetRadius > 10 {
            // Skip blur entirely for low quality and large radius
            content
        } else {
            content.blur(radius: effectiveRadius * 0.5)
        }
    }
}

// MARK: - Quality-Aware Animation

extension Animation {
    /// Returns appropriate animation for current quality level
    public static func qualityAware(
        _ quality: RenderQuality,
        base: Animation = .smooth(duration: 0.3),
    ) -> Animation {
        switch quality.animationComplexity {
        case .full:
            base
        case .reduced:
            .linear(duration: 0.2)
        case .minimal:
            .linear(duration: 0.1)
        }
    }

    /// Spring animation adjusted for quality
    public static func qualityAwareSpring(
        _ quality: RenderQuality,
        response: Double = 0.5,
        dampingFraction: Double = 0.8,
    ) -> Animation {
        switch quality.animationComplexity {
        case .full:
            .spring(response: response, dampingFraction: dampingFraction)
        case .reduced:
            .spring(response: response * 0.7, dampingFraction: dampingFraction)
        case .minimal:
            .linear(duration: 0.15)
        }
    }
}

#endif
