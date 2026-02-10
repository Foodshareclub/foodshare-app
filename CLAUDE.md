# Foodshare Android

**Version:** 3.0.2 | **Kotlin:** 2.0.21 | **Android:** 28-35 | **Swift:** 6.0 | **Status:** Production

> Android companion app for Foodshare - a food sharing platform connecting people with surplus food to those who need it.

---

## Quick Reference

```bash
# Build & Install
./gradlew assembleDebug           # Build debug APK
./gradlew assembleRelease         # Build release APK
./gradlew installDebug            # Install to connected device

# Testing
./gradlew test                    # Run unit tests
./gradlew connectedAndroidTest    # Run instrumented tests

# Swift Core (shared with iOS)
./gradlew testSwift               # Run Swift tests (36 tests)
./gradlew buildSwiftDebug         # Cross-compile Swift for Android (debug)
./gradlew buildSwiftRelease       # Cross-compile Swift for Android (release)
./gradlew cleanSwift              # Clean Swift build artifacts
```

---

## Tech Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Kotlin | 2.0.21 |
| Shared Core | Swift (via JNI) | 6.0 |
| UI | Jetpack Compose + Material 3 | BOM 2024.12.01 |
| Architecture | MVVM + Clean Architecture | - |
| Backend | Self-hosted Supabase (supabase-kt) | 3.0.3 |
| DI | Hilt | 2.51.1 |
| Navigation | Compose Navigation | 2.8.5 |
| Database | Room | 2.6.1 |
| Network | Ktor (OkHttp) | 3.0.2 |
| Images | Coil | 2.7.0 |
| Location | Play Services | 21.3.0 |
| Maps | Maps Compose | 4.3.0 |

---

## Project Structure

```
app/src/main/kotlin/com/foodshare/
├── MainActivity.kt                    # Entry point
├── FoodShareApplication.kt            # Application class with Hilt
│
├── swift/                             # Swift JNI integration
│   ├── FoodshareCoreNative.kt         # JNI native method declarations
│   ├── FoodshareCore.kt               # High-level Kotlin API
│   ├── FoodshareSdk.kt                # SDK facade
│   └── ErrorModels.kt                 # Error mapping
│
├── core/                              # Core infrastructure (37 modules)
│   ├── accessibility/                 # A11y audit, semantic helpers
│   ├── analytics/                     # Event tracking, metrics
│   ├── batch/                         # Batch operations
│   ├── cache/                         # Caching layer (memory, disk)
│   ├── deeplink/                      # Deep link handling
│   ├── error/                         # Legacy error types
│   ├── errors/                        # Error handling, mapping
│   ├── experiments/                   # A/B testing
│   ├── featureflags/                  # Feature flag management
│   ├── forms/                         # Form validation helpers
│   ├── gamification/                  # Points, badges, streaks
│   ├── geo/                           # Geolocation utilities
│   ├── input/                         # Input sanitization
│   ├── localization/                  # i18n bridge
│   ├── matching/                      # Food matching algorithms
│   ├── media/                         # Image/video handling
│   ├── moderation/                    # Content moderation
│   ├── network/                       # Network resilience, BFF models
│   ├── notifications/                 # Push notification handling
│   ├── offline/                       # Offline-first support
│   ├── optimistic/                    # Optimistic updates
│   ├── pagination/                    # Cursor-based pagination
│   ├── performance/                   # Performance monitoring
│   ├── prefetch/                      # Data prefetching
│   ├── push/                          # FCM integration
│   ├── ratelimit/                     # Rate limiting
│   ├── rating/                        # Rating system
│   ├── realtime/                      # Supabase Realtime subscriptions
│   ├── recommendations/               # ML recommendations
│   ├── repository/                    # Base repository patterns
│   ├── search/                        # Search infrastructure
│   ├── security/                      # Security utilities
│   ├── swift/                         # Swift runtime loader
│   ├── sync/                          # Data sync (delta, conflict)
│   ├── transformation/                # Data transformers
│   ├── utilities/                     # General utilities
│   └── validation/                    # ValidationBridge (Swift integration)
│
├── features/                          # Feature modules (17 screens)
│   ├── activity/                      # Activity feed
│   ├── auth/                          # Login, signup, password reset
│   ├── challenges/                    # Community challenges
│   ├── create/                        # Create listing wizard
│   ├── debug/                         # Debug screens (dev only)
│   ├── feed/                          # Main food feed
│   ├── forum/                         # Community forum
│   ├── listing/                       # Listing detail
│   ├── map/                           # Map view (PostGIS)
│   ├── messaging/                     # Chat, conversations
│   ├── mylistings/                    # User's listings
│   ├── notifications/                 # Notification center
│   ├── onboarding/                    # First-run experience
│   ├── profile/                       # User profile, settings
│   ├── reviews/                       # Reviews, ratings
│   ├── search/                        # Search UI
│   └── settings/                      # App settings
│
├── data/repository/                   # Supabase repository implementations
│   ├── SupabaseAuthRepository.kt
│   ├── SupabaseChatRepository.kt
│   ├── SupabaseFavoritesRepository.kt
│   ├── SupabaseFeedRepository.kt
│   ├── SupabaseListingRepository.kt
│   ├── SupabaseReviewRepository.kt
│   └── SupabaseSearchRepository.kt
│
├── domain/
│   ├── model/                         # Domain models (Kotlin)
│   │   ├── FoodListing.kt
│   │   ├── UserProfile.kt
│   │   ├── ChatMessage.kt, ChatRoom.kt
│   │   └── Review.kt
│   └── repository/                    # Repository interfaces
│
├── di/                                # Hilt dependency injection
│   └── AppModule.kt
│
└── ui/                                # Shared UI layer
    ├── components/                    # Reusable Compose components
    ├── design/                        # Design tokens
    ├── navigation/                    # NavHost, routes
    └── theme/                         # Liquid Glass theme system
        ├── LiquidGlassColors.kt
        ├── LiquidGlassTypography.kt
        ├── LiquidGlassSpacing.kt
        └── LiquidGlassAnimations.kt

foodshare-core/                        # Symlink → ../foodshare-core
├── Sources/FoodshareCore/
│   ├── Models/                        # Shared Swift models
│   ├── Validation/                    # Validators (shared with iOS)
│   ├── Utilities/                     # TextSanitizer, InputSanitizer
│   └── JNI/                           # JNI exports
│       ├── JNITypes.swift             # Type definitions
│       └── Generated/                 # @_cdecl exports
├── Tests/                             # 36+ Swift tests
└── scripts/build-android.sh           # Cross-compilation

supabase/                              # Symlink → ../foodshare-backend
app/src/main/jniLibs/                  # Compiled Swift .so files
├── arm64-v8a/libFoodshareCore.so
└── x86_64/libFoodshareCore.so
```

---

## Architecture

### Ultra-Thin Client Pattern

| Android Does | Supabase Does |
|--------------|---------------|
| Display data (Compose) | Store/validate data (PostgreSQL) |
| Collect user input | Authorization (RLS policies) |
| Call Supabase client | Business logic (Edge Functions) |
| Offline cache (Room) | Complex queries (PostGIS) |
| Input sanitization (Swift) | Server-side validation |

### Key Patterns

- **MVVM**: ViewModels expose `StateFlow<UiState>` to Compose screens
- **Repository**: Abstract data sources behind interfaces
- **Validation Bridge**: Kotlin delegates to Swift validators via JNI
- **Offline-First**: Room database with sync manager

---

## Swift Integration

FoodshareCore is a Swift package shared with iOS, compiled for Android using Swift SDK for Android.

### Architecture: Fully swift-java

The project uses **swift-java** for all Swift-Kotlin integration:
- **All Core Bridges**: Use swift-java generated classes with SwiftArena (type-safe, automatic memory management)
- **Legacy Bridges**: Some pure Kotlin bridges remain (platform-specific functionality)

```
ValidationBridge (swift-java):
┌────────────────────────────────────────────────────────────────┐
│                      Kotlin Layer                              │
│  ValidationBridge.kt → Generated Java Classes → SwiftArena     │
└────────────────────────────────────────────────────────────────┘
                              │ JNI (auto-generated)
┌────────────────────────────────────────────────────────────────┐
│                      Swift Layer                               │
│   *+SwiftJavaCompat.swift → ListingValidator, AuthValidator    │
└────────────────────────────────────────────────────────────────┘

Other Bridges (manual JNI):
┌────────────────────────────────────────────────────────────────┐
│                      Kotlin Layer                              │
│  MatchingBridge.kt → FoodshareCore.kt → FoodshareCoreNative    │
└────────────────────────────────────────────────────────────────┘
                              │ JNI (System.loadLibrary)
┌────────────────────────────────────────────────────────────────┐
│                      Swift Layer                               │
│   JNIExports.swift → MatchingEngine, GamificationEngine, etc.  │
└────────────────────────────────────────────────────────────────┘
```

### Key Integration Files

| File | Purpose |
|------|---------|
| `java/.../swift/generated/*.java` | swift-java generated classes |
| `core/validation/ValidationBridge.kt` | Uses swift-java generated classes |
| `swift/FoodshareCoreNative.kt` | Legacy JNI `external fun` declarations |
| `swift/FoodshareCore.kt` | Legacy high-level Kotlin API |
| `foodshare-core/.../JNI/Generated/*+SwiftJavaCompat.swift` | @_cdecl exports for swift-java |
| `foodshare-core/.../JNI/JNIExports.swift` | Legacy @_cdecl exports |

### Validation Example (swift-java)

```kotlin
// In ViewModel
val result = ValidationBridge.validateListing(title, description, quantity)
if (!result.isValid) {
    _uiState.update { it.copy(errors = result.errors) }
}

// ValidationBridge uses generated ListingValidator Java class
// with SwiftArena for memory management
```

### Building Swift for Android

```bash
# Prerequisites: Swift 6.0+ with Android SDK
swift sdk list  # Verify Android SDK installed

# Regenerate JNI bindings (when Swift code changes)
./gradlew generateJniBindings

# Build for Android
./gradlew buildSwiftRelease

# Output: app/src/main/jniLibs/{arm64-v8a,x86_64}/libFoodshareCore.so

# Run Swift tests (on host)
./gradlew testSwift
```

### swift-java Migration Status

| Bridge | Status | Notes |
|--------|--------|-------|
| ValidationBridge | **Migrated** | Uses swift-java generated classes |
| MatchingBridge | **Migrated** | Uses swift-java with SwiftArena |
| GamificationBridge | **Migrated** | Uses swift-java with SwiftArena |
| RecommendationBridge | **Migrated** | Uses swift-java with SwiftArena |
| NetworkResilienceBridge | **Migrated** | Uses swift-java with SwiftArena |
| GeoIntelligenceBridge | **Migrated** | Uses swift-java with SwiftArena |
| ImageProcessorBridge | **Migrated** | Uses swift-java with SwiftArena |
| SearchEngineBridge | **Migrated** | Uses swift-java with SwiftArena |
| LocalizationBridge | **Migrated** | Uses swift-java formatters |
| FeatureFlagBridge | **Migrated** | Rollout, versioning, experiments |
| FormStateBridge | **Migrated** | Form validation via Swift engine |
| ErrorBridge | **Migrated** | Error categorization, recovery via Swift |
| BatchOperationsBridge | **Migrated** | Chunk sizing, backoff via Swift |

SwiftKit dependency: `org.swift.swiftkit:swiftkit-core:1.0-SNAPSHOT` (built locally from swift-java repo)

---

## Design System (Liquid Glass)

| Token | File |
|-------|------|
| Colors | `ui/theme/LiquidGlassColors.kt` |
| Typography | `ui/theme/LiquidGlassTypography.kt` |
| Spacing | `ui/theme/LiquidGlassSpacing.kt` |
| Animations | `ui/theme/LiquidGlassAnimations.kt` |

**Components**: GlassCard, GlassButton, GlassTextField, GlassBottomSheet, etc.

---

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| Kotlin | 2.0.21 | Language |
| Compose BOM | 2024.12.01 | UI framework |
| Supabase-kt | 3.0.3 | Backend client |
| Hilt | 2.51.1 | Dependency injection |
| Room | 2.6.1 | Local database |
| Ktor | 3.0.2 | HTTP client |
| Navigation | 2.8.5 | Compose navigation |
| Coil | 2.7.0 | Image loading |
| Maps Compose | 4.3.0 | Google Maps |
| WorkManager | 2.9.1 | Background sync |
| DataStore | 1.1.1 | Preferences |

---

## Environment Variables

Self-hosted Supabase:
- Studio (dashboard): https://studio.foodshare.club
- API: https://api.foodshare.club

Create `local.properties` (not committed):

```properties
SUPABASE_URL=https://api.foodshare.club
SUPABASE_ANON_KEY=your-anon-key
```

Access via `BuildConfig`:

```kotlin
BuildConfig.SUPABASE_URL
BuildConfig.SUPABASE_ANON_KEY
```

---

## Permissions

```xml
<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Camera & Media -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Background Work -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

---

## Testing

### Unit Tests

```bash
./gradlew test
# Location: app/src/test/
```

### Instrumented Tests

```bash
./gradlew connectedAndroidTest
# Location: app/src/androidTest/
```

### Swift Tests

```bash
./gradlew testSwift  # 36 tests
# Location: foodshare-core/Tests/
```

---

## Troubleshooting

### Swift library not loading

```
java.lang.UnsatisfiedLinkError: dlopen failed: library "libFoodshareCore.so" not found
```

**Fix**: Rebuild Swift library:
```bash
./gradlew buildSwiftRelease
# Verify: ls app/src/main/jniLibs/arm64-v8a/
```

### Build fails with native errors

**Fix**: Clean and rebuild:
```bash
./gradlew cleanSwift buildSwiftRelease
```

### Swift SDK not found

**Fix**: Install Swift Android SDK:
```bash
swift sdk install 6.0.3-RELEASE-android-24-0.1
swift sdk list  # Verify installation
```

### Supabase connection fails

**Fix**: Check `local.properties`:
```properties
SUPABASE_URL=https://api.foodshare.club
SUPABASE_ANON_KEY=eyJ...
```

---

## Code Style

- Kotlin 2.0 features (data classes, sealed classes, coroutines)
- Compose with Material 3 + Liquid Glass theme
- ViewModels with `StateFlow<UiState>`
- Coroutines + Flow for async operations
- `@Serializable` data classes for API models

---

## Related Documentation

| Document | Location |
|----------|----------|
| Architecture | `docs/android/ARCHITECTURE.md` |
| Getting Started | `docs/android/GETTING_STARTED.md` |
| Swift Bridge | `docs/android/SWIFT_BRIDGE_REFERENCE.md` |
| Android Workgroup | `docs/android/SWIFT_ANDROID_WORKGROUP.md` |
| Backend | `supabase/CLAUDE.md` |

---

**Last Updated:** January 2026 | **versionCode:** 273
