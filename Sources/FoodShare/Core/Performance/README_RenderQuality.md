# RenderQualityManager Documentation

## Overview

The `RenderQualityManager` provides adaptive rendering quality management for the FoodShare iOS app. It automatically adjusts Liquid Glass effects based on device capabilities, thermal state, memory pressure, and frame rate to maintain smooth 60+ FPS performance on all devices.

## Features

- **Device Capability Detection**: Automatically detects GPU family, RAM, ProMotion support, and screen specifications
- **Thermal State Monitoring**: Reduces quality when device gets hot to prevent thermal throttling
- **Frame Rate Based Auto-Adjustment**: Monitors FPS using CADisplayLink and reduces quality on frame drops
- **Memory Pressure Integration**: Responds to memory warnings and pressure levels
- **Quality Presets**: Four quality levels (ultra, high, medium, low) with optimized settings
- **SwiftUI Environment Integration**: Seamless integration with SwiftUI views
- **Automatic Recovery**: Increases quality when conditions improve

## Architecture

### Quality Levels

```swift
public enum RenderQuality {
    case low      // Minimal effects, optimized for older devices
    case medium   // Balanced quality, glass materials enabled
    case high     // Full effects, GPU rasterization enabled
    case ultra    // Maximum quality for ProMotion devices
}
```

### Quality Settings Per Level

| Setting | Ultra | High | Medium | Low |
|---------|-------|------|--------|-----|
| Blur Intensity | 20 | 15 | 10 | 5 |
| Shadow Radius | 16 | 12 | 8 | 4 |
| Shadow Layers | 3 | 2 | 1 | 1 |
| Glass Material | ✅ | ✅ | ✅ | ❌ |
| GPU Rasterization | ✅ | ✅ | ❌ | ❌ |
| Complex Gradients | ✅ | ✅ | ✅ | ❌ |
| Shimmer Effects | ✅ | ✅ | ✅ | ❌ |
| Parallax | ✅ | ✅ | ❌ | ❌ |

### Device Capability Detection

The manager automatically detects:

```swift
public struct DeviceCapabilities {
    let deviceModel: String           // e.g., "iPhone16,1"
    let totalMemoryGB: Double         // Physical RAM
    let cpuCount: Int                 // Number of CPU cores
    let gpuFamily: GPUFamily          // Apple GPU generation
    let supportsProMotion: Bool       // 120Hz display support
    let maxFrameRate: Int             // Maximum refresh rate
    let screenScale: CGFloat          // Screen scale factor
}
```

#### GPU Family Mapping

| GPU Family | Devices | Recommended Quality |
|------------|---------|---------------------|
| Apple 9 | A17 Pro (iPhone 15 Pro) | Ultra |
| Apple 8 | A16 (iPhone 14/15) | Ultra |
| Apple 7 | A15 (iPhone 13) | High |
| Apple 6 | A14 (iPhone 12) | High |
| Apple 5 | A12/A13 (iPhone 11/XS) | Medium |
| Apple 4 | A11 (iPhone X/8) | Medium |
| Apple 3 | A9/A10 (iPhone 7) | Low |

### Auto-Adjustment Algorithm

The manager continuously monitors:

1. **Frame Rate**: Measures actual FPS using CADisplayLink
2. **Thermal State**: Observes iOS thermal notifications
3. **Memory Pressure**: Integrates with MemoryPressureManager
4. **Battery State**: Detects Low Power Mode

Quality is reduced when:
- FPS drops below target (50 FPS standard, 100 FPS ProMotion) for 3+ consecutive intervals
- Thermal state reaches "serious" or "critical"
- Memory pressure reaches "warning" or "critical"
- Low Power Mode is enabled

Quality is increased when:
- FPS exceeds target + 10 FPS consistently
- At least 10 seconds passed since last reduction
- Thermal state is nominal
- Memory pressure is normal

## Usage

### Basic Integration

#### 1. Initialize in App

```swift
@main
struct FoodShareApp: App {
    init() {
        Task { @MainActor in
            RenderQualityManager.shared.startMonitoring()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .renderQualityAware()
        }
    }
}
```

#### 2. Use in Views

```swift
struct MyView: View {
    @Environment(\.renderQuality) private var quality

    var body: some View {
        VStack {
            Text("Hello")
        }
        .padding()
        .adaptiveGlassEffect() // Automatically adjusts
        .adaptiveShadow()      // Quality-aware shadow
    }
}
```

### Advanced Usage

#### Manual Quality Control

```swift
// Set specific quality level (disables auto-adjustment)
RenderQualityManager.shared.setQuality(.high, autoAdjust: false)

// Reset to recommended quality
RenderQualityManager.shared.resetToRecommended()

// Enable/disable auto-adjustment
RenderQualityManager.shared.setAutoAdjustEnabled(true)
```

#### Temporary Quality Reduction

```swift
// Reduce quality during heavy operations
RenderQualityManager.shared.temporaryReduceQuality(duration: 5.0)

// Perform heavy operation
await performComplexAnimation()

// Quality automatically restores after 5 seconds
```

#### Quality Metrics

```swift
let metrics = RenderQualityManager.shared.getMetrics()
print("Current Quality: \(metrics.currentQuality)")
print("Effective Quality: \(metrics.effectiveQuality)")
print("Average FPS: \(metrics.averageFPS)")
print("Thermal State: \(metrics.thermalState)")
```

### Adaptive Modifiers

#### Adaptive Glass Effect

```swift
view.adaptiveGlassEffect(
    cornerRadius: Spacing.radiusLG,
    borderWidth: 1
)
```

- Ultra/High: Full .ultraThinMaterial with complex gradients
- Medium: .ultraThinMaterial with simple border
- Low: Solid background with reduced opacity

#### Adaptive Shadow

```swift
view.adaptiveShadow(
    color: .black,
    intensity: 1.0
)
```

- Ultra: 3 stacked shadows
- High: 2 stacked shadows
- Medium/Low: Single shadow

#### Adaptive Blur

```swift
view.adaptiveBlur(radius: 20)
```

- Ultra: Up to 30pt blur
- High: Up to 20pt blur
- Medium: Up to 12pt blur
- Low: Up to 6pt blur (or skipped if target > 10)

### Conditional Rendering

```swift
struct MyView: View {
    @Environment(\.renderQuality) private var quality

    var body: some View {
        VStack {
            // Always render
            basicContent

            // Only on medium+ quality
            if quality.enableGlassMaterial {
                glassEffects
            }

            // Only on high+ quality
            if quality.useGPURasterization {
                complexAnimations
            }

            // Only on ultra quality
            if quality == .ultra {
                premiumEffects
            }
        }
    }
}
```

### Quality-Aware Animations

```swift
struct AnimatedView: View {
    @Environment(\.renderQuality) private var quality
    @State private var isExpanded = false

    var body: some View {
        expandableContent
            .animation(.qualityAware(quality), value: isExpanded)
            // Full animation on ultra/high
            // Reduced animation on medium
            // Minimal animation on low
    }
}

// Or use spring animation
.animation(.qualityAwareSpring(quality), value: value)
```

### List Performance

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ComplexGlassCard(item: item)
                .if(quality.useGPURasterization) { view in
                    view.drawingGroup() // GPU rasterization
                }
        }
    }
}
```

## Integration with Existing Systems

### FrameRateMonitor

RenderQualityManager has its own CADisplayLink for quality management. It complements FrameRateMonitor:

- **FrameRateMonitor**: Observability and metrics
- **RenderQualityManager**: Adaptive quality control

Both can run simultaneously without conflict.

### MemoryPressureManager

RenderQualityManager integrates with MemoryPressureManager:

```swift
// Memory pressure affects effective quality
let effectiveQuality = settings.effectiveQuality

// Critical memory pressure → Low quality
// Warning memory pressure → Medium quality max
// Normal memory pressure → No restriction
```

### Notifications

RenderQualityManager posts notifications for observability:

```swift
// Quality changed
NotificationCenter.default.addObserver(
    forName: .renderQualityChanged,
    object: nil,
    queue: .main
) { notification in
    let quality = notification.userInfo?["quality"] as? RenderQuality
}

// Quality reduced
NotificationCenter.default.addObserver(
    forName: .renderQualityReduced,
    object: nil,
    queue: .main
) { notification in
    let reason = notification.userInfo?["reason"] as? String
}

// Quality increased
NotificationCenter.default.addObserver(
    forName: .renderQualityIncreased,
    object: nil,
    queue: .main
) { notification in
    // Handle quality increase
}

// Thermal state changed
NotificationCenter.default.addObserver(
    forName: .thermalStateChanged,
    object: nil,
    queue: .main
) { notification in
    let state = notification.userInfo?["state"] as? ProcessInfo.ThermalState
}
```

## Configuration

```swift
RenderQualityManager.shared.configuration = .init(
    targetMinFPS: 50,                    // FPS target for standard displays
    targetProMotionFPS: 100,             // FPS target for ProMotion displays
    monitoringInterval: 1.0,             // How often to measure FPS
    lowFPSThreshold: 3,                  // Consecutive low readings before reduction
    qualityRecoveryDelay: 10.0,          // Wait before increasing quality
    enableAutoAdjustment: true           // Enable automatic quality adjustment
)
```

## Performance Considerations

### ProMotion Optimization

On ProMotion devices (120Hz):
- Target FPS is 100+ (allows headroom)
- Uses interpolating spring animations for instant response
- Enables full GPU rasterization for complex views

### Memory Efficiency

Quality levels affect memory usage:
- **Ultra**: ~20-30% higher memory usage (complex materials, shadows)
- **High**: ~10-15% higher memory usage
- **Medium**: Baseline memory usage
- **Low**: ~10-15% lower memory usage (simplified effects)

### Battery Impact

Quality levels affect battery life:
- **Ultra**: High GPU usage, suitable for plugged-in devices
- **High**: Balanced GPU usage
- **Medium**: Moderate GPU usage
- **Low**: Minimal GPU usage, optimized for battery life

Low Power Mode automatically caps quality at medium.

## Best Practices

### 1. Always Use Adaptive Modifiers

❌ **Don't**:
```swift
view
    .blur(radius: 20)
    .shadow(radius: 16)
```

✅ **Do**:
```swift
view
    .adaptiveBlur(radius: 20)
    .adaptiveShadow()
```

### 2. Check Quality for Expensive Effects

❌ **Don't**:
```swift
view
    .overlay {
        ComplexParticleSystem()
    }
```

✅ **Do**:
```swift
view
    .overlay {
        if quality >= .high {
            ComplexParticleSystem()
        }
    }
```

### 3. Use GPU Rasterization on Lists

❌ **Don't**:
```swift
ForEach(items) { item in
    ComplexGlassCard(item: item)
}
```

✅ **Do**:
```swift
ForEach(items) { item in
    ComplexGlassCard(item: item)
        .if(quality.useGPURasterization) {
            $0.drawingGroup()
        }
}
```

### 4. Test on Multiple Devices

Always test quality adaptation on:
- ProMotion device (iPhone 13 Pro+)
- Standard device (iPhone SE, iPhone 11)
- Simulator with different thermal states

### 5. Monitor Metrics in Development

Use the quality metrics dashboard (see Examples) to:
- Verify recommended quality is appropriate
- Check FPS stability at each quality level
- Monitor adjustment frequency

## Debugging

### Enable Debug Logging

Debug logging is enabled by default in DEBUG builds:

```swift
#if DEBUG
    print("[RenderQuality] Initialized")
    print("[RenderQuality] Manually set to high")
    print("[RenderQuality] Reduced to medium (reason: low_fps, FPS: 42.3)")
#endif
```

### Quality Metrics Dashboard

Add the quality metrics dashboard to your debug menu:

```swift
#if DEBUG
import RenderQualityManager_Examples

struct DebugMenu: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Quality Metrics") {
                    QualityMetricsDashboardExample()
                }
            }
        }
    }
}
#endif
```

### Force Thermal State (Simulator)

```swift
// Simulate thermal pressure
RenderQualityManager.shared.handleThermalStateChange()

// Manually set quality
RenderQualityManager.shared.setQuality(.low, autoAdjust: false)
```

## Migration Guide

### From Fixed Quality

**Before**:
```swift
view
    .blur(radius: 20)
    .shadow(radius: 16)
    .background(.ultraThinMaterial)
```

**After**:
```swift
view
    .adaptiveBlur(radius: 20)
    .adaptiveShadow()
    .adaptiveGlassEffect()
```

### From Manual Quality Checks

**Before**:
```swift
if ProcessInfo.processInfo.physicalMemory > 4_000_000_000 {
    // High quality effects
}
```

**After**:
```swift
@Environment(\.renderQuality) private var quality

if quality >= .high {
    // High quality effects
}
```

## Troubleshooting

### Quality Never Increases

**Cause**: Recent quality reduction prevents immediate increase

**Solution**: Wait for `qualityRecoveryDelay` (default 10s) or call `resetToRecommended()`

### Quality Too Conservative

**Cause**: Device capabilities detected incorrectly

**Solution**: Manually set recommended quality:
```swift
RenderQualityManager.shared.setQuality(.high, autoAdjust: true)
```

### FPS Still Drops

**Cause**: Quality reduction not sufficient, other performance issues

**Solution**:
1. Profile with Instruments (Core Animation)
2. Check for main thread blocking
3. Reduce number of simultaneous animations
4. Use LazyVStack/LazyHStack for long lists

### Memory Warnings Persist

**Cause**: Quality reduction doesn't free enough memory

**Solution**: Integrate with MemoryPressureManager cache eviction

## Version History

### v1.0.0 (2026-01-31)
- Initial implementation
- Device capability detection (GPU, RAM, ProMotion)
- Thermal state monitoring
- Frame rate based auto-adjustment
- Four quality levels with adaptive settings
- SwiftUI environment integration
- Adaptive modifiers (glass, shadow, blur)
- Quality-aware animations
- Memory pressure integration

## Future Enhancements

- [ ] Metal feature set detection for precise GPU capabilities
- [ ] Per-view quality override
- [ ] Quality preset profiles (battery saver, performance, balanced)
- [ ] Analytics integration for quality metrics
- [ ] A/B testing framework for quality thresholds
- [ ] Machine learning based quality prediction
- [ ] Haptic feedback on quality changes (accessibility)

## Related Files

- `RenderQualityManager.swift` - Main implementation
- `RenderQualityManager+Examples.swift` - Usage examples and previews
- `FrameRateMonitor.swift` - Frame rate observability
- `MemoryPressureManager.swift` - Memory pressure monitoring
- `GlassModifiers.swift` - Liquid Glass design system modifiers

## License

Copyright © 2026 FoodShare. All rights reserved.
