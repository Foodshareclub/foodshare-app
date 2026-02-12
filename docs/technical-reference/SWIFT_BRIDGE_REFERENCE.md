# Swift-Kotlin Bridge Reference

**Version:** 1.0.0 | **Status:** Production | **Last Updated:** January 2026

> Comprehensive reference for all Swift-Kotlin bridges in FoodshareCore

---

## Overview

The Foodshare Android app shares ~95% of its business logic with iOS via the Swift FoodshareCore package. This document catalogs all bridges and their usage.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Kotlin ViewModels                           │
│         (UI logic, state management, compose)                  │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    Kotlin Bridges                              │
│    (ValidationBridge, GeoIntelligenceBridge, etc.)            │
└────────────────────────────────────────────────────────────────┘
                              │ JNI (swift-java generated)
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    FoodshareCore (Swift)                       │
│    (Validators, Engines, Utilities, Algorithms)               │
└────────────────────────────────────────────────────────────────┘
```

---

## Bridge Catalog

### Phase 1-2: Validation & BFF

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `ValidationBridge` | `Validation/` | Entity validation |
| `BFFModels` | `BFF/` | Backend-for-Frontend types |

**Usage:**
```kotlin
val result = ValidationBridge.validateListing(title, description, quantity)
if (!result.isValid) {
    showErrors(result.errors)
}
```

---

### Phase 3: ML Recommendations

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `MLRecommendationBridge` | `Recommendations/` | Personalized feed ranking |

**Features:**
- Collaborative filtering
- Content-based ranking
- Contextual bandits
- Cold start handling

---

### Phase 5: Conflict Resolution

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `DeltaSyncBridge` | `Sync/` | 3-way merge, CRDT support |

**CRDT Types:**
- LWW-Register (last-write-wins)
- G-Counter (grow-only)
- PN-Counter (positive-negative)
- OR-Set (observed-remove)

---

### Phase 6: Image Processing

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `ImagePipelineBridge` | `Media/` | Image optimization |

**Features:**
- Format detection (JPEG, PNG, WebP, HEIC)
- Dimension extraction
- Thumbnail generation
- Duplicate detection via perceptual hashing

---

### Phase 7: Search

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `SearchEngineBridge` | `Search/` | NLP-powered search |

**Features:**
- Query parsing with intent extraction
- Spell correction
- Synonym expansion
- Relevance scoring

---

### Phase 9: Analytics

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `AdvancedAnalyticsBridge` | `Analytics/` | Event batching & tracking |

**Features:**
- Event compression
- Offline buffering
- Session management
- Funnel tracking

---

### Phase 10: Notifications

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `NotificationOrchestratorBridge` | `Notifications/` | Push optimization |

**Features:**
- Quiet hours
- Priority calculation
- Consolidation
- Engagement prediction

---

### Phase 11: Gamification

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `GamificationEngineBridge` | `Gamification/` | Points, badges, challenges |

**Features:**
- Points with multipliers
- Badge tiers (bronze/silver/gold/platinum)
- Streak tracking
- Leaderboard ranking

---

### Phase 12: Geographic Intelligence

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `GeoIntelligenceBridge` | `Geo/` | Advanced geospatial |

**Features:**
- Haversine distance
- DBSCAN clustering
- Geofencing
- Route optimization
- Hotspot detection
- Geohash encoding

**Usage:**
```kotlin
val distance = GeoIntelligenceBridge.calculateDistance(from, to)
val clusters = GeoIntelligenceBridge.clusterLocations(locations, config)
val route = GeoIntelligenceBridge.optimizeRoute(start, waypoints)
```

---

### Phase 13: Content Moderation

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `ContentModerationBridge` | `Moderation/` | ML-based moderation |

**Features:**
- Profanity detection
- Toxicity scoring
- Spam detection
- Sensitive content flagging
- User trust scores

**Usage:**
```kotlin
val result = ContentModerationBridge.analyzeText(text, context)
if (!result.isApproved) {
    if (result.requiresReview) {
        queueForReview()
    } else {
        showRejection(result.flags)
    }
}
```

---

### Phase 14: Rate Limiting

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `RateLimitBridge` | `RateLimiting/` | Quota management |

**Features:**
- Operation permission checks
- Quota tracking
- Burst detection
- Availability prediction
- Adaptive limits

**Usage:**
```kotlin
val permission = RateLimitBridge.canPerformOperation("listings.create", userId)
if (!permission.allowed) {
    showRetryAfter(permission.retryAfter)
}
RateLimitBridge.recordOperation("listings.create", userId)
```

---

### Phase 15: Performance

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `PerformanceMonitorBridge` | `Performance/` | App profiling |

**Features:**
- Frame timing (FPS, jank)
- Memory profiling
- Network analysis
- Startup tracking
- Performance budgets

---

### Phase 16: Accessibility

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `AccessibilityEngineBridge` | `Accessibility/` | WCAG compliance |

**Features:**
- Contrast checking (WCAG A/AA/AAA)
- Color blindness simulation
- Touch target validation
- Text scaling
- Screen reader optimization
- Accessibility audit

**Usage:**
```kotlin
val result = AccessibilityEngineBridge.checkContrast(foreground, background)
if (!result.normalTextPasses) {
    applyRecommendation(result.recommendation)
}

val audit = AccessibilityEngineBridge.auditScreen(elements)
showAccessibilityScore(audit.score)
```

---

### Phase 17: A/B Testing

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `ExperimentBridge` | `Experiments/` | A/B testing |

**Features:**
- Deterministic variant assignment
- Feature flags
- Thompson Sampling (MAB)
- Statistical significance
- Exposure tracking

**Usage:**
```kotlin
val variant = ExperimentBridge.getVariant("new_feed", userId, experiment)
when (variant.id) {
    "control" -> showControlFeed()
    "treatment" -> showNewFeed()
}
ExperimentBridge.trackExposure("new_feed", variant.id, userId)
```

---

### Phase 18: Error Recovery

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `ErrorRecoveryBridge` | `ErrorRecovery/` | Smart retry |

**Features:**
- Error classification
- Recovery strategies
- Circuit breaker
- Exponential backoff
- User-friendly messages

---

### Phase 19: Security

| Bridge | Swift Module | Purpose |
|--------|--------------|---------|
| `SecurityBridge` | `Security/` | Encryption & auth |

**Features:**
- AES-GCM encryption
- Secure random generation
- Attestation verification
- Security audits

---

## Building Bridges

### Generate JNI Bindings

```bash
./gradlew generateJniBindings
```

### Build Swift for Android

```bash
./gradlew buildSwiftRelease
# Or manually:
cd foodshare-core && ./scripts/build-android.sh all release
```

### Run Swift Tests

```bash
./gradlew testSwift
```

---

## Best Practices

1. **Minimize JNI Crossings** - Batch operations when possible
2. **Offline Fallback** - All bridges have Kotlin fallback implementations
3. **Thread Safety** - All Swift types are `Sendable`
4. **Immutability** - Use immutable data classes
5. **Type Safety** - Leverage Kotlin serialization

---

## Troubleshooting

### Bridge Not Found
Ensure Swift libraries are in `jniLibs/`:
```
app/src/main/jniLibs/
├── arm64-v8a/libFoodshareCore.so
└── x86_64/libFoodshareCore.so
```

### JNI Errors
Regenerate bindings:
```bash
./gradlew clean generateJniBindings buildSwiftRelease
```

### Swift Compilation Failures
Check Swift toolchain:
```bash
swift --version  # Should be 6.0+
swift sdk list   # Should show Android SDK
```

---

*Generated: January 2026 | Foodshare Android Swift Bridge Reference*
