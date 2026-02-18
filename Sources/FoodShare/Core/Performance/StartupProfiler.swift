//
//  StartupProfiler.swift
//  FoodShare
//
//  Measures cold start performance with detailed phase breakdown.
//  Tracks time from process launch to first interactive frame.
//
//  Features:
//  - Phase-based timing (pre-main, init, UI ready, interactive)
//  - Automatic metric reporting
//  - Performance threshold warnings
//  - Historical tracking for regression detection
//


#if !SKIP
import Foundation
import Observation
import OSLog
#if !SKIP
import QuartzCore
#endif
import SwiftUI

// MARK: - Startup Phase

public enum StartupPhase: String, CaseIterable, Sendable {
    case preMain = "Pre-main"
    case appInit = "App Init"
    case servicesInit = "Services Init"
    case authCheck = "Auth Check"
    case configLoad = "Config Load"
    case uiReady = "UI Ready"
    case firstFrame = "First Frame"
    case interactive = "Interactive"

    public var targetDurationMs: Double {
        switch self {
        case .preMain: 200
        case .appInit: 100
        case .servicesInit: 300
        case .authCheck: 200
        case .configLoad: 150
        case .uiReady: 200
        case .firstFrame: 100
        case .interactive: 250
        }
    }

    public var icon: String {
        switch self {
        case .preMain: "cpu"
        case .appInit: "app.badge"
        case .servicesInit: "gearshape.2"
        case .authCheck: "lock.shield"
        case .configLoad: "slider.horizontal.3"
        case .uiReady: "rectangle.on.rectangle"
        case .firstFrame: "play.rectangle"
        case .interactive: "hand.tap"
        }
    }
}

// MARK: - Phase Timing

public struct PhaseTiming: Sendable, Identifiable {
    public let id = UUID()
    public let phase: StartupPhase
    public let startTime: CFAbsoluteTime
    public let endTime: CFAbsoluteTime
    public let durationMs: Double

    public var isWithinTarget: Bool {
        durationMs <= phase.targetDurationMs
    }

    public var percentOfTarget: Double {
        guard phase.targetDurationMs > 0 else { return 0 }
        return (durationMs / phase.targetDurationMs) * 100
    }

    public var formattedDuration: String {
        String(format: "%.0fms", durationMs)
    }
}

// MARK: - Startup Report

public struct StartupReport: Sendable {
    public let timings: [PhaseTiming]
    public let totalDurationMs: Double
    public let processStartTime: CFAbsoluteTime
    public let interactiveTime: CFAbsoluteTime
    public let date: Date

    public var targetTotalMs: Double { 1500 } // 1.5s target

    public var isWithinTarget: Bool {
        totalDurationMs <= targetTotalMs
    }

    public var percentOfTarget: Double {
        guard targetTotalMs > 0 else { return 0 }
        return (totalDurationMs / targetTotalMs) * 100
    }

    public var formattedTotal: String {
        if totalDurationMs >= 1000 {
            return String(format: "%.2fs", totalDurationMs / 1000)
        }
        return String(format: "%.0fms", totalDurationMs)
    }

    public var slowestPhase: PhaseTiming? {
        timings.max { $0.durationMs < $1.durationMs }
    }

    public var phasesExceedingTarget: [PhaseTiming] {
        timings.filter { !$0.isWithinTarget }
    }

    public func timing(for phase: StartupPhase) -> PhaseTiming? {
        timings.first { $0.phase == phase }
    }
}

// MARK: - Startup Profiler

@MainActor
@Observable
public final class StartupProfiler {
    public static let shared = StartupProfiler()

    // MARK: - Observable Properties

    public private(set) var currentPhase: StartupPhase?
    public private(set) var lastReport: StartupReport?
    public private(set) var isComplete = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "StartupProfiler")
    private var phaseTimings: [StartupPhase: (start: CFAbsoluteTime, end: CFAbsoluteTime?)] = [:]
    private var processStartTime: CFAbsoluteTime = 0
    private var historicalReports: [StartupReport] = []
    private let maxHistorySize = 10

    // Pre-main time capture (set before main() if possible)
    private static var preMainStartTime: CFAbsoluteTime = 0
    private static var preMainEndTime: CFAbsoluteTime = 0

    // MARK: - Initialization

    private init() {
        // Capture approximate process start time
        // Note: For accurate pre-main timing, use DYLD_PRINT_STATISTICS
        processStartTime = StartupProfiler.preMainEndTime > 0
            ? StartupProfiler.preMainStartTime
            : CFAbsoluteTimeGetCurrent() - ProcessInfo.processInfo.systemUptime + getProcessStartTime()
    }

    // MARK: - Static Pre-Main Capture

    /// Call this as early as possible in main() to capture pre-main end time
    public static func markPreMainComplete() {
        preMainEndTime = CFAbsoluteTimeGetCurrent()
    }

    /// Call this from a load() function or static initializer for earliest timing
    public static func markPreMainStart() {
        preMainStartTime = CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Phase Tracking

    /// Begin timing a phase
    public func beginPhase(_ phase: StartupPhase) {
        guard !isComplete else {
            logger.warning("[Startup] Attempted to begin phase after startup complete: \(phase.rawValue)")
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        phaseTimings[phase] = (start: now, end: nil)
        currentPhase = phase

        #if DEBUG
            logger.debug("[Startup] Phase began: \(phase.rawValue)")
        #endif
    }

    /// End timing a phase
    public func endPhase(_ phase: StartupPhase) {
        guard var timing = phaseTimings[phase], timing.end == nil else {
            logger.warning("[Startup] Phase not started or already ended: \(phase.rawValue)")
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        timing.end = now
        phaseTimings[phase] = timing

        let durationMs = (now - timing.start) * 1000
        let target = phase.targetDurationMs

        #if DEBUG
            if durationMs > target {
                logger
                    .warning(
                        "[Startup] Phase \(phase.rawValue) exceeded target: \(String(format: "%.0f", durationMs))ms (target: \(String(format: "%.0f", target))ms)",
                    )
            } else {
                logger.debug("[Startup] Phase ended: \(phase.rawValue) - \(String(format: "%.0f", durationMs))ms")
            }
        #endif
    }

    /// Convenience method to time a phase block
    public func measurePhase<T>(_ phase: StartupPhase, block: () async throws -> T) async rethrows -> T {
        beginPhase(phase)
        defer { endPhase(phase) }
        return try await block()
    }

    /// Synchronous version for non-async phases
    public func measurePhase<T>(_ phase: StartupPhase, block: () throws -> T) rethrows -> T {
        beginPhase(phase)
        defer { endPhase(phase) }
        return try block()
    }

    // MARK: - Startup Completion

    /// Mark startup as complete and generate report
    public func markStartupComplete() {
        guard !isComplete else { return }

        // End any open phases
        if let current = currentPhase, phaseTimings[current]?.end == nil {
            endPhase(current)
        }

        isComplete = true
        currentPhase = nil

        // Generate report
        let report = generateReport()
        lastReport = report

        // Store in history
        historicalReports.append(report)
        if historicalReports.count > maxHistorySize {
            historicalReports.removeFirst()
        }

        // Log summary
        logStartupSummary(report)

        // Report to metrics
        Task {
            await reportMetrics(report)
        }
    }

    /// Reset profiler for a new startup cycle (useful for testing)
    public func reset() {
        phaseTimings.removeAll()
        currentPhase = nil
        isComplete = false
        lastReport = nil
        processStartTime = CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Report Generation

    private func generateReport() -> StartupReport {
        let now = CFAbsoluteTimeGetCurrent()

        // Build phase timings
        var timings: [PhaseTiming] = []

        // Add pre-main if available
        if StartupProfiler.preMainEndTime > 0 {
            let preMainDuration = (StartupProfiler.preMainEndTime - processStartTime) * 1000
            timings.append(PhaseTiming(
                phase: .preMain,
                startTime: processStartTime,
                endTime: StartupProfiler.preMainEndTime,
                durationMs: max(0.0, preMainDuration),
            ))
        }

        // Add tracked phases in order
        for phase in StartupPhase.allCases where phase != .preMain {
            if let timing = phaseTimings[phase] {
                let endTime = timing.end ?? now
                let durationMs = (endTime - timing.start) * 1000
                timings.append(PhaseTiming(
                    phase: phase,
                    startTime: timing.start,
                    endTime: endTime,
                    durationMs: durationMs,
                ))
            }
        }

        // Calculate total duration
        let interactiveTime = phaseTimings[.interactive]?.end ?? now
        let totalDurationMs = (interactiveTime - processStartTime) * 1000

        return StartupReport(
            timings: timings,
            totalDurationMs: totalDurationMs,
            processStartTime: processStartTime,
            interactiveTime: interactiveTime,
            date: Date(),
        )
    }

    // MARK: - Metrics Reporting

    private func reportMetrics(_ report: StartupReport) async {
        await MetricsReporter.shared.recordRequest(
            endpoint: "startup/cold_start",
            method: "LIFECYCLE",
            statusCode: report.isWithinTarget ? 200 : 0,
            durationMs: Int(report.totalDurationMs),
            cacheHit: false
        )
        // Report individual phase timings
        for timing in report.timings {
            await MetricsReporter.shared.recordRequest(
                endpoint: "startup/phase/\(timing.phase.rawValue)",
                method: "LIFECYCLE",
                statusCode: timing.isWithinTarget ? 200 : 0,
                durationMs: Int(timing.durationMs),
                cacheHit: false
            )
        }
    }

    // MARK: - Logging

    private func logStartupSummary(_ report: StartupReport) {
        let status = report.isWithinTarget ? "✅" : "⚠️"

        logger.info("""
        \(status) [Startup] Complete in \(report.formattedTotal)
        """)

        #if DEBUG
            logger.debug("""

            ╔══════════════════════════════════════════════════════════════╗
            ║                     STARTUP PROFILE                          ║
            ╠══════════════════════════════════════════════════════════════╣
            """)

            for timing in report.timings {
                let status = timing.isWithinTarget ? "✓" : "⚠"
                let bar = String(repeating: "█", count: min(20, Int(timing.percentOfTarget / 5)))
                let padding = String(repeating: "░", count: max(0, 20 - bar.count))
                logger.debug(
                    "║ \(status) \(timing.phase.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0)) │ \(timing.formattedDuration.padding(toLength: 7, withPad: " ", startingAt: 0)) │ \(bar)\(padding) ║",
                )
            }

            logger.debug("""
            ╠══════════════════════════════════════════════════════════════╣
            ║ Total: \(report.formattedTotal.padding(
                toLength: 8,
                withPad: " ",
                startingAt: 0,
            ))                                              ║
            ║ Target: \("1.5s".padding(toLength: 7, withPad: " ", startingAt: 0)) │ Status: \(report.isWithinTarget
                ? "PASSED ✓"
                : "FAILED ✗")                       ║
            ╚══════════════════════════════════════════════════════════════╝

            """)

            // Warn about slow phases
            if !report.phasesExceedingTarget.isEmpty {
                logger.warning("⚠️  Phases exceeding target:")
                for timing in report.phasesExceedingTarget {
                    logger.warning(
                        "   • \(timing.phase.rawValue): \(timing.formattedDuration) (target: \(String(format: "%.0fms", timing.phase.targetDurationMs)))",
                    )
                }
            }
        #endif
    }

    // MARK: - Historical Analysis

    /// Returns average startup time over recent launches
    public func getAverageStartupTime() -> Double {
        guard !historicalReports.isEmpty else { return 0 }
        let total = historicalReports.reduce(0) { $0 + $1.totalDurationMs }
        return total / Double(historicalReports.count)
    }

    /// Returns trend (positive = slower, negative = faster)
    public func getStartupTrend() -> Double {
        guard historicalReports.count >= 2 else { return 0 }
        let recent = historicalReports.suffix(3).map(\.totalDurationMs)
        let older = historicalReports.prefix(3).map(\.totalDurationMs)

        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)

        return recentAvg - olderAvg
    }

    // MARK: - Process Start Time

    private func getProcessStartTime() -> CFAbsoluteTime {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        guard sysctl(&mib, UInt32(mib.count), &kinfo, &size, nil, 0) == 0 else {
            return 0
        }

        let startTime = kinfo.kp_proc.p_starttime
        return CFAbsoluteTime(startTime.tv_sec) + CFAbsoluteTime(startTime.tv_usec) / 1_000_000.0
    }
}

// MARK: - SwiftUI Integration

/// View modifier that marks first frame rendered
public struct FirstFrameModifier: ViewModifier {
    @State private var hasRendered = false

    public func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasRendered else { return }
                hasRendered = true

                Task { @MainActor in
                    // End UI ready phase and begin first frame tracking
                    StartupProfiler.shared.endPhase(.uiReady)
                    StartupProfiler.shared.beginPhase(.firstFrame)

                    // Wait for next run loop to ensure frame is actually rendered
                    try? await Task.sleep(for: .milliseconds(16)) // ~1 frame at 60fps
                    StartupProfiler.shared.endPhase(.firstFrame)
                    StartupProfiler.shared.beginPhase(.interactive)
                }
            }
    }
}

/// View modifier that marks view as interactive
public struct InteractiveModifier: ViewModifier {
    @State private var isInteractive = false

    public func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isInteractive else { return }

                // Use a small delay to ensure UI is truly interactive
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !isInteractive else { return }
                    isInteractive = true

                    StartupProfiler.shared.endPhase(.interactive)
                    StartupProfiler.shared.markStartupComplete()
                }
            }
    }
}

extension View {
    /// Marks when this view's first frame is rendered
    public func trackFirstFrame() -> some View {
        modifier(FirstFrameModifier())
    }

    /// Marks when this view becomes interactive (completes startup)
    public func trackInteractive() -> some View {
        modifier(InteractiveModifier())
    }
}

// MARK: - SwiftUI Startup Debug View

#if DEBUG
    public struct StartupDebugView: View {
        @State private var profiler = StartupProfiler.shared

        public init() {}

        public var body: some View {
            if let report = profiler.lastReport {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                        Text("Startup: \(report.formattedTotal)")
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Image(systemName: report.isWithinTarget
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill")
                            .foregroundStyle(report.isWithinTarget ? .green : .orange)
                    }

                    if let slowest = report.slowestPhase, !slowest.isWithinTarget {
                        Text("Slowest: \(slowest.phase.rawValue) (\(slowest.formattedDuration))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Spacing.sm)
                #if !SKIP
                .background(.ultraThinMaterial)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
#endif


#endif
