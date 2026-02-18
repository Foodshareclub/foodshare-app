
#if !SKIP
import Foundation
import OSLog
#if !SKIP
import QuartzCore
#endif
#if !SKIP
import UIKit
#endif

// MARK: - Frame Rate Monitor

/// Observable class for monitoring app frame rate and detecting frame drops
/// Optimized for 120Hz ProMotion displays
@MainActor
@Observable
public final class FrameRateMonitor {

    // MARK: - Properties

    public static let shared = FrameRateMonitor()

    /// Current frames per second
    public private(set) var currentFPS: Double = 0

    /// Average FPS over the monitoring session
    public private(set) var averageFPS: Double = 0

    /// Number of dropped frames detected
    public private(set) var droppedFrameCount = 0

    /// Whether the device supports ProMotion (120Hz)
    public private(set) var isProMotionDevice = false

    /// Whether monitoring is currently active
    public private(set) var isMonitoring = false

    /// Target frame rate (60 or 120 based on device)
    public private(set) var targetFrameRate: Double = 60

    /// Current performance tier based on FPS
    public var performanceTier: PerformanceTier {
        if currentFPS >= 100 { return .excellent }
        if currentFPS >= 60 { return .good }
        if currentFPS >= 30 { return .poor }
        return .critical
    }

    // Private
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0
    private var totalFrameCount = 0
    private var accumulatedTime: CFTimeInterval = 0
    private var fpsHistory: [Double] = []
    private let historySize = 60 // 1 second of history at 60fps

    // Thresholds
    private let proMotionFrameTime: CFTimeInterval = 1.0 / 120.0 // 8.33ms
    private let standardFrameTime: CFTimeInterval = 1.0 / 60.0 // 16.67ms
    private var targetFrameTime: CFTimeInterval { 1.0 / targetFrameRate }
    private let dropThreshold: CFTimeInterval = 1.5 // 150% of target

    // Logger
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FrameRateMonitor")

    // MARK: - Performance Tier

    public enum PerformanceTier: String, Sendable {
        case excellent = "Excellent"
        case good = "Good"
        case poor = "Poor"
        case critical = "Critical"

        public var color: String {
            switch self {
            case .excellent: "brandGreen"
            case .good: "success"
            case .poor: "warning"
            case .critical: "error"
            }
        }

        public var description: String {
            switch self {
            case .excellent: "120+ FPS - ProMotion optimal"
            case .good: "60+ FPS - Smooth"
            case .poor: "30-60 FPS - May experience jank"
            case .critical: "<30 FPS - Significant performance issues"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        checkProMotionSupport()
    }

    // MARK: - Public API

    /// Starts monitoring frame rate
    public func startMonitoring() {
        guard !isMonitoring else { return }

        #if DEBUG
            isMonitoring = true
            resetMetrics()

            displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: Float(targetFrameRate),
                preferred: Float(targetFrameRate),
            )
            displayLink?.add(to: .main, forMode: .common)
        #endif
    }

    /// Stops monitoring frame rate
    public func stopMonitoring() {
        guard isMonitoring else { return }

        displayLink?.invalidate()
        displayLink = nil
        isMonitoring = false
    }

    /// Resets all metrics
    public func resetMetrics() {
        currentFPS = 0
        averageFPS = 0
        droppedFrameCount = 0
        frameCount = 0
        totalFrameCount = 0
        accumulatedTime = 0
        lastTimestamp = 0
        fpsHistory.removeAll()
    }

    /// Returns a summary of the current performance
    public func getPerformanceSummary() -> PerformanceSummary {
        PerformanceSummary(
            currentFPS: currentFPS,
            averageFPS: averageFPS,
            droppedFrames: droppedFrameCount,
            tier: performanceTier,
            isProMotion: isProMotionDevice,
            monitoringDuration: accumulatedTime,
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

        // Detect dropped frames
        if deltaTime > targetFrameTime * dropThreshold {
            let droppedCount = Int((deltaTime / targetFrameTime).rounded()) - 1
            droppedFrameCount += max(0, droppedCount)
        }

        frameCount += 1
        totalFrameCount += 1
        accumulatedTime += deltaTime

        // Calculate FPS every 0.5 seconds for smoother updates
        if accumulatedTime >= 0.5 {
            currentFPS = Double(frameCount) / accumulatedTime

            // Update history
            fpsHistory.append(currentFPS)
            if fpsHistory.count > historySize {
                fpsHistory.removeFirst()
            }

            // Calculate average
            averageFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)

            // Reset for next interval
            frameCount = 0
            accumulatedTime = 0
        }
    }

    // MARK: - Private Helpers

    private func checkProMotionSupport() {
        // Check if device supports ProMotion (120Hz)
        // This is determined by the maximum frame rate of the main screen
        let maxFrameRate = UIScreen.main.maximumFramesPerSecond

        isProMotionDevice = maxFrameRate >= 120
        targetFrameRate = Double(maxFrameRate)
    }
}

// MARK: - Performance Summary

public struct PerformanceSummary: Sendable {
    public let currentFPS: Double
    public let averageFPS: Double
    public let droppedFrames: Int
    public let tier: FrameRateMonitor.PerformanceTier
    public let isProMotion: Bool
    public let monitoringDuration: TimeInterval

    public var formattedCurrentFPS: String {
        String(format: "%.1f", currentFPS)
    }

    public var formattedAverageFPS: String {
        String(format: "%.1f", averageFPS)
    }

    public var formattedDuration: String {
        let minutes = Int(monitoringDuration) / 60
        let seconds = Int(monitoringDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Frame Rate Reporter

/// Reports frame rate metrics to the analytics service
public actor FrameRateReporter {

    public static let shared = FrameRateReporter()

    private var reportingTask: Task<Void, Never>?
    private let reportingInterval: TimeInterval = 60 // Report every minute
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FrameRateReporter")

    private init() {}

    /// Starts periodic frame rate reporting
    public func startReporting() {
        reportingTask?.cancel()

        reportingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.reportingInterval))

                guard !Task.isCancelled else { break }

                let summary = await MainActor.run {
                    FrameRateMonitor.shared.getPerformanceSummary()
                }

                await self.reportMetrics(summary)
            }
        }
    }

    /// Stops periodic frame rate reporting
    public func stopReporting() {
        reportingTask?.cancel()
        reportingTask = nil
    }

    private func reportMetrics(_ summary: PerformanceSummary) async {
        // Integration point with MetricsReporter
        // This would send frame rate metrics to your analytics backend
        logger.info("""
        [FrameRate] Performance Report:
        - Current FPS: \(summary.formattedCurrentFPS)
        - Average FPS: \(summary.formattedAverageFPS)
        - Dropped Frames: \(summary.droppedFrames)
        - Tier: \(summary.tier.rawValue)
        - Duration: \(summary.formattedDuration)
        """)
    }
}

// MARK: - SwiftUI Environment

import SwiftUI

private struct FrameRateMonitorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: FrameRateMonitor = // Note: This is safe because FrameRateMonitor is
        // @MainActor isolated
        // and SwiftUI environment values are always accessed on the main thread
        MainActor.assumeIsolated {
            FrameRateMonitor.shared
        }
}

extension EnvironmentValues {
    public var frameRateMonitor: FrameRateMonitor {
        get { self[FrameRateMonitorKey.self] }
        set { self[FrameRateMonitorKey.self] = newValue }
    }
}

#endif
