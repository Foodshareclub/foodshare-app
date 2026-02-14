//
//  RenderQualityManager+Examples.swift
//  FoodShare
//
//  Usage examples and integration patterns for RenderQualityManager.
//  This file demonstrates how to use adaptive rendering in your views.
//

#if DEBUG

    import SwiftUI

    // MARK: - App Integration Example

    /* 
     Initialize RenderQualityManager in your App or RootView:

     ```swift
     @main
     struct FoodShareApp: App {
         @State private var qualityManager = RenderQualityManager.shared

         init() {
             // Start monitoring on app launch
             Task { @MainActor in
                 RenderQualityManager.shared.startMonitoring()
             }
         }

         var body: some Scene {
             WindowGroup {
                 RootView()
                     .renderQualityAware() // Inject quality into environment
             }
         }
     }
     ```
     */

    // MARK: - View Usage Examples

    /// Example 1: Adaptive glass card with quality-aware effects
    struct AdaptiveGlassCardExample: View {
        @Environment(\.renderQuality) private var quality

        var body: some View {
            VStack(spacing: Spacing.md) {
                Text("Adaptive Glass Card")
                    .font(.DesignSystem.headlineMedium)

                Text("Quality: \(quality.description)")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(Spacing.lg)
            .adaptiveGlassEffect() // Automatically adjusts based on quality
        }
    }

    /// Example 2: Conditional complex effects based on quality
    struct ConditionalEffectsExample: View {
        @Environment(\.renderQuality) private var quality

        var body: some View {
            VStack {
                Text("Hello, World!")
                    .font(.DesignSystem.displayLarge)
            }
            .padding()
            .background {
                if quality.enableGlassMaterial {
                    // Full glass effect on high-quality devices
                    RoundedRectangle(cornerRadius: quality.cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            if quality.enableComplexGradients {
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandGreen.opacity(0.1),
                                        Color.clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                )
                            }
                        }
                } else {
                    // Simple background on low-quality devices
                    RoundedRectangle(cornerRadius: quality.cornerRadius)
                        .fill(Color.DesignSystem.glassBackground)
                }
            }
            .adaptiveShadow() // Quality-aware shadow
        }
    }

    /// Example 3: List with GPU rasterization on high-quality devices
    struct AdaptiveListExample: View {
        @Environment(\.renderQuality) private var quality
        let items = Array(0 ..< 100)

        var body: some View {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(items, id: \.self) { item in
                        listItemView(item)
                            .if(quality.useGPURasterization) { view in
                                view.drawingGroup() // GPU rasterization for complex cards
                            }
                    }
                }
                .padding()
            }
        }

        private func listItemView(_ item: Int) -> some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Item \(item)")
                    .font(.DesignSystem.headlineSmall)

                Text("Description")
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(Spacing.md)
            .adaptiveGlassEffect()
        }
    }

    /// Example 4: Animations with quality-aware duration
    struct AdaptiveAnimationExample: View {
        @Environment(\.renderQuality) private var quality
        @State private var isExpanded = false

        var body: some View {
            VStack {
                Button("Toggle") {
                    isExpanded.toggle()
                }
                .buttonStyle(.borderedProminent)

                if isExpanded {
                    detailView
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.qualityAware(quality), value: isExpanded)
        }

        private var detailView: some View {
            VStack(spacing: Spacing.md) {
                ForEach(0 ..< 5) { index in
                    Text("Detail \(index)")
                        .padding()
                        .adaptiveGlassEffect()
                        .if(quality.animationComplexity == .full) { view in
                            view.staggeredAppearance(index: index)
                        }
                }
            }
        }
    }

    /// Example 5: Blur effect with adaptive radius
    struct AdaptiveBlurExample: View {
        @Environment(\.renderQuality) private var quality

        var body: some View {
            ZStack {
                // Background image
                Color.blue.opacity(0.3)

                // Blurred overlay
                VStack {
                    Text("Blurred Content")
                        .font(.DesignSystem.displayMedium)
                }
                .padding()
                .background(.ultraThinMaterial)
                .adaptiveBlur(radius: 20) // Automatically reduces on low-quality devices
            }
        }
    }

    /// Example 6: Manual quality control for specific views
    struct ManualQualityControlExample: View {
        @State private var qualityManager = RenderQualityManager.shared

        var body: some View {
            VStack(spacing: Spacing.lg) {
                Text("Current Quality: \(qualityManager.currentQuality.description)")
                    .font(.DesignSystem.headlineLarge)

                Text("FPS: \(String(format: "%.1f", qualityManager.averageFPS))")
                    .font(.DesignSystem.bodyLarge)

                HStack(spacing: Spacing.md) {
                    ForEach(RenderQuality.allCases, id: \.self) { quality in
                        Button(quality.description) {
                            qualityManager.setQuality(quality)
                        }
                        .buttonStyle(.bordered)
                        .disabled(qualityManager.currentQuality == quality)
                    }
                }

                Button("Reset to Recommended") {
                    qualityManager.resetToRecommended()
                }
                .buttonStyle(.borderedProminent)

                Toggle("Auto-Adjust", isOn: Binding(
                    get: { qualityManager.isAutoAdjustEnabled },
                    set: { qualityManager.setAutoAdjustEnabled($0) },
                ))
            }
            .padding()
        }
    }

    /// Example 7: Quality metrics dashboard
    struct QualityMetricsDashboardExample: View {
        @State private var qualityManager = RenderQualityManager.shared
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        var body: some View {
            List {
                Section("Current State") {
                    metricRow("Quality", value: qualityManager.currentQuality.description)
                    metricRow("Effective Quality", value: qualityManager.settings.effectiveQuality.description)
                    metricRow("FPS", value: String(format: "%.1f", qualityManager.averageFPS))
                }

                Section("Device Capabilities") {
                    metricRow("Model", value: qualityManager.deviceCapabilities.deviceModel)
                    metricRow("GPU", value: qualityManager.deviceCapabilities.gpuFamily.rawValue)
                    metricRow(
                        "Memory",
                        value: String(format: "%.1f GB", qualityManager.deviceCapabilities.totalMemoryGB),
                    )
                    metricRow("ProMotion", value: qualityManager.deviceCapabilities.supportsProMotion ? "Yes" : "No")
                    metricRow("Max FPS", value: "\(qualityManager.deviceCapabilities.maxFrameRate)")
                }

                Section("Environment") {
                    metricRow("Thermal State", value: thermalStateDescription)
                    metricRow("Memory Pressure", value: qualityManager.settings.memoryPressure.description)
                    metricRow("Low Power Mode", value: qualityManager.settings.isLowPowerModeEnabled ? "Yes" : "No")
                    metricRow("Adjustments", value: "\(qualityManager.performanceAdjustmentCount)")
                }

                Section("Quality Settings") {
                    metricRow("Blur Intensity", value: "\(Int(qualityManager.currentQuality.blurIntensity))")
                    metricRow("Shadow Radius", value: "\(Int(qualityManager.currentQuality.shadowRadius))")
                    metricRow("Shadow Layers", value: "\(qualityManager.currentQuality.shadowLayers)")
                    metricRow("Glass Material", value: qualityManager.currentQuality.enableGlassMaterial ? "Yes" : "No")
                    metricRow(
                        "GPU Rasterization",
                        value: qualityManager.currentQuality.useGPURasterization
                            ? "Yes"
                            : "No",
                    )
                    metricRow(
                        "Shimmer Effects",
                        value: qualityManager.currentQuality.enableShimmerEffects
                            ? "Yes"
                            : "No",
                    )
                }
            }
            .onReceive(timer) { _ in
                // Force update
            }
        }

        private func metricRow(_ label: String, value: String) -> some View {
            HStack {
                Text(label)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Spacer()
                Text(value)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .bold()
            }
            .font(.DesignSystem.bodyMedium)
        }

        private var thermalStateDescription: String {
            switch qualityManager.thermalState {
            case .nominal: "Nominal"
            case .fair: "Fair"
            case .serious: "Serious"
            case .critical: "Critical"
            @unknown default: "Unknown"
            }
        }
    }

    // MARK: - Helper Extension

    extension View {
        /// Conditionally apply a view modifier
        @ViewBuilder
        func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
            if condition {
                transform(self)
            } else {
                self
            }
        }
    }

    // MARK: - Preview

    #Preview("Adaptive Glass Card") {
        AdaptiveGlassCardExample()
            .renderQualityAware()
            .padding()
    }

    #Preview("Conditional Effects") {
        ConditionalEffectsExample()
            .renderQualityAware()
            .padding()
    }

    #Preview("Adaptive List") {
        AdaptiveListExample()
            .renderQualityAware()
    }

    #Preview("Adaptive Animation") {
        AdaptiveAnimationExample()
            .renderQualityAware()
            .padding()
    }

    #Preview("Manual Quality Control") {
        ManualQualityControlExample()
    }

    #Preview("Quality Metrics Dashboard") {
        QualityMetricsDashboardExample()
    }

#endif
