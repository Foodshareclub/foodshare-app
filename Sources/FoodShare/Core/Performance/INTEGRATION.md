# RenderQualityManager Integration Guide

## Quick Start (5 Minutes)

### Step 1: Initialize in App Entry Point

Add to your `FoodShareApp.swift` or `RootView.swift`:

```swift
import SwiftUI

@main
struct FoodShareApp: App {

    init() {
        // Initialize quality monitoring on app launch
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

### Step 2: Update Existing Glass Components

Find existing glass effects and replace with adaptive versions:

#### Before:
```swift
VStack {
    Text("Food Item")
}
.padding()
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 20))
.shadow(radius: 12)
```

#### After:
```swift
VStack {
    Text("Food Item")
}
.padding()
.adaptiveGlassEffect() // Automatically adapts to device
```

### Step 3: Use Quality in Custom Views

```swift
struct FoodItemCard: View {
    @Environment(\.renderQuality) private var quality
    let item: FoodItem

    var body: some View {
        VStack {
            // Always show basic content
            basicContent

            // Only show expensive effects on capable devices
            if quality.enableShimmerEffects {
                shimmerOverlay
            }
        }
        .adaptiveGlassEffect()
    }
}
```

## Migration Checklist

Use this checklist to migrate existing views:

### Glass Effects
- [ ] Replace `.glassEffect()` with `.adaptiveGlassEffect()`
- [ ] Replace manual `.blur(radius:)` with `.adaptiveBlur(radius:)`
- [ ] Replace manual `.shadow()` with `.adaptiveShadow()`

### Lists and ScrollViews
- [ ] Add `.drawingGroup()` conditionally based on `quality.useGPURasterization`
- [ ] Verify LazyVStack/LazyHStack are used (not VStack/HStack)

### Animations
- [ ] Replace `.animation(.spring(), value:)` with `.animation(.qualityAware(quality), value:)`
- [ ] Remove animations on low-quality when not essential

### Complex Effects
- [ ] Gate shimmer effects with `quality.enableShimmerEffects`
- [ ] Gate parallax with `quality.enableParallax`
- [ ] Gate complex gradients with `quality.enableComplexGradients`

## Component Update Examples

### GlassButton

```swift
// Before
struct GlassButton: View {
    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// After
struct GlassButton: View {
    @Environment(\.renderQuality) private var quality

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(GlassButtonStyle(quality: quality))
    }
}

struct GlassButtonStyle: ButtonStyle {
    let quality: RenderQuality

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .adaptiveGlassEffect()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.qualityAware(quality), value: configuration.isPressed)
    }
}
```

### GlassCard

```swift
// Before
struct GlassCard<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 12)
    }
}

// After
struct GlassCard<Content: View>: View {
    @Environment(\.renderQuality) private var quality
    let content: Content

    var body: some View {
        content
            .padding()
            .adaptiveGlassEffect(cornerRadius: quality.cornerRadius)
    }
}
```

### List Performance

```swift
// Before
ScrollView {
    VStack {
        ForEach(items) { item in
            GlassListingCard(item: item)
        }
    }
}

// After
ScrollView {
    LazyVStack { // Use LazyVStack instead of VStack
        ForEach(items) { item in
            GlassListingCard(item: item)
                .if(quality.useGPURasterization) { view in
                    view.drawingGroup() // GPU rasterization
                }
        }
    }
}
```

## Testing Strategy

### 1. Device Testing

Test on these device classes:

#### Ultra Quality Devices
- iPhone 15 Pro / 15 Pro Max (A17 Pro, ProMotion)
- iPhone 14 Pro / 14 Pro Max (A16, ProMotion)
- iPad Pro (M1/M2, ProMotion)

Expected: Ultra quality, 120Hz smooth, all effects enabled

#### High Quality Devices
- iPhone 15 / 15 Plus (A16)
- iPhone 14 / 14 Plus (A15)
- iPhone 13 / 13 Pro (A15)

Expected: High quality, 60Hz smooth, most effects enabled

#### Medium Quality Devices
- iPhone 12 / 12 Pro (A14)
- iPhone 11 / 11 Pro (A13)
- iPhone XS / XR (A12)

Expected: Medium quality, 60Hz, glass materials enabled

#### Low Quality Devices
- iPhone SE (2nd/3rd gen) (A13/A15)
- iPhone X / 8 (A11)
- iPhone 7 (A10)

Expected: Low quality, 60Hz, simplified effects

### 2. Thermal Testing

Simulate thermal pressure:

```swift
// In Debug menu
Button("Simulate Thermal Pressure") {
    // Run heavy workload
    for _ in 0..<1000 {
        _ = (0..<10000).map { $0 * $0 }
    }
}
```

Expected: Quality automatically reduces, effects simplify

### 3. Memory Testing

Trigger memory warnings:

```swift
// In Debug menu
Button("Trigger Memory Warning") {
    MemoryPressureManager.shared.handleMemoryWarning()
}
```

Expected: Quality reduces to low/medium based on severity

### 4. Low Power Mode Testing

Enable Low Power Mode in Settings

Expected: Quality caps at medium, battery life improves

## Performance Benchmarks

Use these benchmarks to validate performance:

### Feed View (100 items)
| Device Class | Target FPS | Memory | Quality |
|--------------|------------|--------|---------|
| Ultra | 100+ | <200MB | Ultra |
| High | 60+ | <150MB | High |
| Medium | 60 | <120MB | Medium |
| Low | 60 | <100MB | Low |

### Detail View (Complex)
| Device Class | Target FPS | Memory | Quality |
|--------------|------------|--------|---------|
| Ultra | 100+ | <150MB | Ultra |
| High | 60+ | <120MB | High |
| Medium | 60 | <100MB | Medium |
| Low | 60 | <80MB | Low |

### Map View (Annotations)
| Device Class | Target FPS | Memory | Quality |
|--------------|------------|--------|---------|
| Ultra | 100+ | <250MB | Ultra |
| High | 60+ | <200MB | High |
| Medium | 60 | <150MB | Medium |
| Low | 55+ | <120MB | Low |

## Monitoring in Production

### Analytics Events

Track these events for quality insights:

```swift
// Quality reduced
NotificationCenter.default.addObserver(
    forName: .renderQualityReduced
) { notification in
    analytics.track("quality_reduced", properties: [
        "from": notification.userInfo?["quality"],
        "reason": notification.userInfo?["reason"],
        "fps": notification.userInfo?["fps"],
        "device": deviceModel
    ])
}

// Thermal throttling
NotificationCenter.default.addObserver(
    forName: .thermalStateChanged
) { notification in
    analytics.track("thermal_state_changed", properties: [
        "state": notification.userInfo?["state"],
        "quality": currentQuality
    ])
}
```

### Crash Reporting

Add quality context to crash reports:

```swift
Crashlytics.crashlytics().setCustomValue(
    RenderQualityManager.shared.currentQuality.description,
    forKey: "render_quality"
)

Crashlytics.crashlytics().setCustomValue(
    RenderQualityManager.shared.averageFPS,
    forKey: "average_fps"
)
```

### Performance Monitoring

Track quality distribution:

```swift
PerformanceMonitor.shared.record(
    "render_quality",
    type: .custom,
    metadata: [
        "quality": currentQuality.description,
        "device": deviceModel,
        "fps": String(format: "%.1f", averageFPS)
    ]
)
```

## Rollout Strategy

### Phase 1: Canary (5% of users)
- Enable for 5% of users
- Monitor crash rates, FPS metrics
- Collect quality reduction frequency
- Duration: 1 week

### Phase 2: Beta (25% of users)
- Expand to 25% if no issues
- A/B test against fixed quality
- Measure battery impact
- Duration: 1 week

### Phase 3: Full Rollout (100%)
- Roll out to all users
- Continue monitoring quality metrics
- Tune thresholds based on data

## Common Issues

### Issue: Quality Too Conservative

**Symptoms**: High-end devices using medium quality

**Diagnosis**:
```swift
let metrics = RenderQualityManager.shared.getMetrics()
print("Recommended: \(metrics.deviceCapabilities.recommendedQuality)")
print("Current: \(metrics.currentQuality)")
```

**Fix**: Adjust GPU family detection or manually set recommended quality

### Issue: Frequent Quality Changes

**Symptoms**: Quality changes multiple times per minute

**Diagnosis**: Check frame rate stability

**Fix**: Increase `lowFPSThreshold` or `qualityRecoveryDelay`:
```swift
RenderQualityManager.shared.configuration.lowFPSThreshold = 5
RenderQualityManager.shared.configuration.qualityRecoveryDelay = 20.0
```

### Issue: Quality Never Increases

**Symptoms**: Quality stays at low after initial reduction

**Diagnosis**: Check thermal state and memory pressure

**Fix**: Ensure thermal state returns to nominal, memory pressure clears

### Issue: ProMotion Devices Not Detected

**Symptoms**: iPhone 15 Pro showing as 60Hz

**Diagnosis**:
```swift
print("Max FPS: \(UIScreen.main.maximumFramesPerSecond)")
```

**Fix**: Verify ProMotion is not disabled in accessibility settings

## Feature Flags

Integrate with your feature flag system:

```swift
let qualityConfig = FeatureFlags.shared.getConfig("adaptive_quality")

RenderQualityManager.shared.configuration = .init(
    targetMinFPS: qualityConfig.targetMinFPS ?? 50,
    targetProMotionFPS: qualityConfig.targetProMotionFPS ?? 100,
    enableAutoAdjustment: qualityConfig.enableAutoAdjustment ?? true
)
```

## A/B Testing

Test quality impact on engagement:

```swift
// Variant A: Auto-adaptive quality
if experimentVariant == "auto_quality" {
    RenderQualityManager.shared.setAutoAdjustEnabled(true)
}

// Variant B: Fixed high quality
if experimentVariant == "fixed_quality" {
    RenderQualityManager.shared.setQuality(.high, autoAdjust: false)
}

// Track metrics
analytics.track("session_duration")
analytics.track("crashes")
analytics.track("battery_drain")
```

## Support

For issues or questions:
- Review README_RenderQuality.md for detailed documentation
- Check Examples file for implementation patterns
- Profile with Instruments if FPS issues persist
- File bug reports with device model, quality level, and FPS metrics

## Version

Current: v1.0.0 (2026-01-31)
