//
//  PerformanceAuditView.swift
//  FoodShare
//
//  DEBUG overlay for real-time performance monitoring.
//  Shows FPS, memory, CPU, thermal state, and animation diagnostics.
//
//  Usage:
//  - Shake device 3x in DEBUG builds to toggle
//  - Or use .performanceOverlay() modifier
//
//  Features:
//  - Real-time FPS monitoring (120Hz aware)
//  - Memory pressure tracking
//  - Thermal state warnings
//  - Animation jank detection
//  - Network request counter
//


#if !SKIP
import SwiftUI

#if DEBUG

    // MARK: - Performance Metrics Model

    @MainActor
    @Observable
    final class PerformanceMetrics {
        static let shared = PerformanceMetrics()

        // Frame rate
        var currentFPS: Double = 0
        var averageFPS: Double = 0
        var droppedFrames = 0
        var isProMotion = false

        // Memory
        var memoryUsageMB: Double = 0
        var memoryPressureLevel: MemoryPressureLevel = .normal
        var peakMemoryMB: Double = 0

        // Thermal
        var thermalState: ProcessInfo.ThermalState = .nominal

        // Network
        var activeNetworkRequests = 0
        var totalNetworkRequests = 0

        // Animation
        var activeAnimations = 0
        var jankEvents = 0

        // Timing
        var lastUpdateTime: Date = .now
        var monitoringDuration: TimeInterval = 0

        private var updateTimer: Timer?
        private var startTime: Date?

        private init() {}

        func startMonitoring() {
            startTime = .now
            FrameRateMonitor.shared.startMonitoring()

            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMetrics()
                }
            }
        }

        func stopMonitoring() {
            updateTimer?.invalidate()
            updateTimer = nil
            FrameRateMonitor.shared.stopMonitoring()
        }

        private func updateMetrics() {
            // Frame rate from FrameRateMonitor
            let summary = FrameRateMonitor.shared.getPerformanceSummary()
            currentFPS = summary.currentFPS
            averageFPS = summary.averageFPS
            droppedFrames = summary.droppedFrames
            isProMotion = summary.isProMotion

            // Memory
            updateMemoryMetrics()

            // Thermal
            thermalState = ProcessInfo.processInfo.thermalState

            // Duration
            if let start = startTime {
                monitoringDuration = Date.now.timeIntervalSince(start)
            }

            lastUpdateTime = .now
        }

        private func updateMemoryMetrics() {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }

            if result == KERN_SUCCESS {
                memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
                peakMemoryMB = max(peakMemoryMB, memoryUsageMB)

                // Determine pressure level
                if memoryUsageMB > 300 {
                    memoryPressureLevel = .critical
                } else if memoryUsageMB > 200 {
                    memoryPressureLevel = .warning
                } else {
                    memoryPressureLevel = .normal
                }
            }
        }

        func recordNetworkRequest() {
            activeNetworkRequests += 1
            totalNetworkRequests += 1
        }

        func completeNetworkRequest() {
            activeNetworkRequests = max(0, activeNetworkRequests - 1)
        }

        func recordJankEvent() {
            jankEvents += 1
        }

        func reset() {
            droppedFrames = 0
            peakMemoryMB = memoryUsageMB
            jankEvents = 0
            totalNetworkRequests = 0
            startTime = .now
            monitoringDuration = 0
            FrameRateMonitor.shared.resetMetrics()
        }

        enum MemoryPressureLevel: String {
            case normal = "Normal"
            case warning = "Warning"
            case critical = "Critical"

            var color: Color {
                switch self {
                case .normal: Color.DesignSystem.success
                case .warning: Color.DesignSystem.warning
                case .critical: Color.DesignSystem.error
                }
            }
        }
    }

    // MARK: - Performance Audit View

    struct PerformanceAuditView: View {
        @State private var metrics = PerformanceMetrics.shared
        @State private var isExpanded = true
        @State private var selectedTab = 0

        var body: some View {
            VStack(spacing: 0) {
                // Header
                header

                if isExpanded {
                    // Tab selector
                    tabSelector

                    // Content
                    TabView(selection: $selectedTab) {
                        overviewTab.tag(0)
                        memoryTab.tag(1)
                        animationTab.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 140.0)
                }
            }
            #if !SKIP
            .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            #else
            .background(Color.DesignSystem.glassSurface.opacity(0.15))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .padding(Spacing.sm)
            .onAppear {
                metrics.startMonitoring()
            }
            .onDisappear {
                metrics.stopMonitoring()
            }
        }

        // MARK: - Header

        private var header: some View {
            HStack {
                // FPS indicator
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(fpsColor)
                        .frame(width: 8.0, height: 8)

                    Text("\(Int(metrics.currentFPS)) FPS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    if metrics.isProMotion {
                        Text("120Hz")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.DesignSystem.primary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Thermal state
                if metrics.thermalState != .nominal {
                    thermalIndicator
                }

                // Expand/Collapse
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                // Reset button
                Button {
                    metrics.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }

        // MARK: - Tab Selector

        private var tabSelector: some View {
            HStack(spacing: Spacing.sm) {
                tabButton("Overview", icon: "gauge", index: 0)
                tabButton("Memory", icon: "memorychip", index: 1)
                tabButton("Animation", icon: "waveform.path", index: 2)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xs)
        }

        private func tabButton(_ title: String, icon: String, index: Int) -> some View {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    selectedTab = index
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(selectedTab == index ? Color.DesignSystem.primary : .secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    selectedTab == index
                        ? Color.DesignSystem.primary.opacity(0.15)
                        : Color.clear,
                )
                .clipShape(Capsule())
            }
        }

        // MARK: - Overview Tab

        private var overviewTab: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.lg) {
                    metricCard(
                        title: "Average FPS",
                        value: String(format: "%.1f", metrics.averageFPS),
                        color: averageFpsColor,
                    )

                    metricCard(
                        title: "Dropped",
                        value: "\(metrics.droppedFrames)",
                        color: metrics.droppedFrames > 10 ? Color.DesignSystem.error : Color.DesignSystem.success,
                    )

                    metricCard(
                        title: "Network",
                        value: "\(metrics.activeNetworkRequests)/\(metrics.totalNetworkRequests)",
                        color: .secondary,
                    )
                }

                // Duration
                Text("Monitoring: \(formattedDuration)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
        }

        // MARK: - Memory Tab

        private var memoryTab: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.lg) {
                    metricCard(
                        title: "Current",
                        value: String(format: "%.0f MB", metrics.memoryUsageMB),
                        color: metrics.memoryPressureLevel.color,
                    )

                    metricCard(
                        title: "Peak",
                        value: String(format: "%.0f MB", metrics.peakMemoryMB),
                        color: .secondary,
                    )

                    metricCard(
                        title: "Status",
                        value: metrics.memoryPressureLevel.rawValue,
                        color: metrics.memoryPressureLevel.color,
                    )
                }

                // Memory bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(metrics.memoryPressureLevel.color)
                            .frame(width: geo.size.width * min(metrics.memoryUsageMB / 300, 1))
                    }
                }
                .frame(height: 8.0)
                .padding(.horizontal, Spacing.md)

                HStack {
                    Text("0 MB")
                    Spacer()
                    Text("150 MB")
                    Spacer()
                    Text("300 MB")
                }
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Spacing.md)
            }
            .padding(Spacing.md)
        }

        // MARK: - Animation Tab

        private var animationTab: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.lg) {
                    metricCard(
                        title: "Jank Events",
                        value: "\(metrics.jankEvents)",
                        color: metrics.jankEvents > 5 ? Color.DesignSystem.warning : Color.DesignSystem.success,
                    )

                    metricCard(
                        title: "Frame Budget",
                        value: metrics.isProMotion ? "8.3ms" : "16.7ms",
                        color: .secondary,
                    )

                    metricCard(
                        title: "Target",
                        value: metrics.isProMotion ? "120" : "60",
                        color: Color.DesignSystem.primary,
                    )
                }

                // Performance tier
                HStack {
                    Text("Performance Tier:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(performanceTier)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(fpsColor)
                }

                // Recommendations
                if metrics.droppedFrames > 10 || metrics.memoryPressureLevel != .normal {
                    recommendationBanner
                }
            }
            .padding(Spacing.md)
        }

        // MARK: - Components

        private func metricCard(title: String, value: String, color: Color) -> some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }

        private var thermalIndicator: some View {
            HStack(spacing: 4) {
                Image(systemName: thermalIcon)
                    .font(.system(size: 10))
                Text(thermalText)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(thermalColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(thermalColor.opacity(0.15))
            .clipShape(Capsule())
        }

        private var recommendationBanner: some View {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                Text(recommendation)
                    .font(.system(size: 9))
            }
            .foregroundStyle(Color.DesignSystem.warning)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(Color.DesignSystem.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        // MARK: - Computed Properties

        private var fpsColor: Color {
            if metrics.currentFPS >= 100 { return Color.DesignSystem.success }
            if metrics.currentFPS >= 60 { return Color.DesignSystem.primary }
            if metrics.currentFPS >= 30 { return Color.DesignSystem.warning }
            return Color.DesignSystem.error
        }

        private var averageFpsColor: Color {
            if metrics.averageFPS >= 100 { return Color.DesignSystem.success }
            if metrics.averageFPS >= 60 { return Color.DesignSystem.primary }
            if metrics.averageFPS >= 30 { return Color.DesignSystem.warning }
            return Color.DesignSystem.error
        }

        private var performanceTier: String {
            if metrics.averageFPS >= 100 { return "Excellent" }
            if metrics.averageFPS >= 60 { return "Good" }
            if metrics.averageFPS >= 30 { return "Poor" }
            return "Critical"
        }

        private var thermalIcon: String {
            switch metrics.thermalState {
            case .nominal: return "thermometer.medium"
            case .fair: return "thermometer.medium"
            case .serious: return "thermometer.high"
            case .critical: return "flame.fill"
            @unknown default: return "thermometer.medium"
            }
        }

        private var thermalText: String {
            switch metrics.thermalState {
            case .nominal: return "Cool"
            case .fair: return "Warm"
            case .serious: return "Hot"
            case .critical: return "Throttling"
            @unknown default: return "Unknown"
            }
        }

        private var thermalColor: Color {
            switch metrics.thermalState {
            case .nominal: return Color.DesignSystem.success
            case .fair: return Color.DesignSystem.warning
            case .serious: return Color.DesignSystem.error
            case .critical: return Color.DesignSystem.error
            @unknown default: return .secondary
            }
        }

        private var recommendation: String {
            if metrics.memoryPressureLevel == .critical {
                return "High memory usage - consider clearing caches"
            }
            if metrics.droppedFrames > 20 {
                return "Many dropped frames - check for heavy operations"
            }
            if metrics.droppedFrames > 10 {
                return "Some frame drops - use .drawingGroup() on complex views"
            }
            return "Performance looks good!"
        }

        private var formattedDuration: String {
            let minutes = Int(metrics.monitoringDuration) / 60
            let seconds = Int(metrics.monitoringDuration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Performance Overlay Modifier

    struct PerformanceOverlayModifier: ViewModifier {
        @State private var showOverlay = false

        func body(content: Content) -> some View {
            content
                .overlay(alignment: .topTrailing) {
                    if showOverlay {
                        PerformanceAuditView()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .onShake {
                    withAnimation(.spring(response: 0.3)) {
                        showOverlay.toggle()
                    }
                }
        }
    }

    extension View {
        /// Adds a performance overlay that can be toggled by shaking the device (DEBUG only)
        func performanceOverlay() -> some View {
            modifier(PerformanceOverlayModifier())
        }
    }

    // MARK: - Shake Gesture Detection

    extension UIWindow {
        override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                NotificationCenter.default.post(name: .deviceDidShake, object: nil)
            }
        }
    }

    // onShake and deviceDidShake are defined in LocalizationEnvironment.swift

    // MARK: - Preview

    #Preview {
        ZStack {
            Color.DesignSystem.background.ignoresSafeArea()

            VStack {
                Spacer()
                Text("Shake device to toggle overlay")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) {
            PerformanceAuditView()
        }
    }

#endif

#endif
