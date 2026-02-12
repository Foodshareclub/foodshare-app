# Foodshare Cross-Platform Architecture

How Swift on Android fits into Foodshare's ultra-thin client architecture.

---

## Architecture Overview

Foodshare uses an **ultra-thin client / thick server** architecture:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                                │
│                    (Thick Server - All Business Logic)                  │
├─────────────────────────────────────────────────────────────────────────┤
│  PostgreSQL + PostGIS  │  Edge Functions  │  Auth  │  Storage  │  Realtime │
│  (Data + RLS Policies) │  (Server Logic)  │ (PKCE) │ (Images)  │  (Sync)   │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
          ┌─────────▼─────────┐       ┌─────────▼─────────┐
          │   iOS App         │       │   Android App     │
          │   (Ultra-Thin)    │       │   (Ultra-Thin)    │
          ├───────────────────┤       ├───────────────────┤
          │                   │       │                   │
          │  ┌─────────────┐  │       │  ┌─────────────┐  │
          │  │  SwiftUI    │  │       │  │  Jetpack    │  │
          │  │  (Native)   │  │       │  │  Compose    │  │
          │  └──────┬──────┘  │       │  └──────┬──────┘  │
          │         │         │       │         │         │
          │  ┌──────▼──────┐  │       │  ┌──────▼──────┐  │
          │  │   Shared    │◄─┼───────┼─►│   Shared    │  │
          │  │   Swift     │  │       │  │   Swift     │  │
          │  │   Domain    │  │       │  │ (via JNI)   │  │
          │  └──────┬──────┘  │       │  └──────┬──────┘  │
          │         │         │       │         │         │
          │  ┌──────▼──────┐  │       │  ┌──────▼──────┐  │
          │  │  Supabase   │  │       │  │  Supabase   │  │
          │  │  Client     │  │       │  │  Client     │  │
          │  └─────────────┘  │       │  └─────────────┘  │
          │                   │       │                   │
          └───────────────────┘       └───────────────────┘
```

---

## Layer Responsibilities

### Thick Server (Supabase)

The backend handles **all business logic**:

| Component | Responsibility |
|-----------|----------------|
| PostgreSQL | Data storage, complex queries, PostGIS geospatial |
| RLS Policies | Authorization logic (who can access what) |
| Edge Functions | Business workflows, notifications, integrations |
| Auth | User authentication, session management |
| Storage | Image upload, CDN delivery |
| Realtime | Live updates, presence |

### Thin Clients (iOS/Android)

Clients are **presentation-focused**:

| Layer | iOS | Android |
|-------|-----|---------|
| **UI** | SwiftUI | Jetpack Compose |
| **State** | @Observable | ViewModel + State |
| **Domain** | Swift Models | Swift Models (via JNI) |
| **Network** | supabase-swift | supabase-swift (via JNI) |

---

## Why This Works for Swift on Android

### SwiftUI is NOT Available on Android

This is a **feature limitation**, but our architecture handles it well:

- UI is platform-native anyway (SwiftUI vs. Compose)
- Domain layer is platform-agnostic Swift
- Business logic lives on the server

Per [forum discussions](https://forums.swift.org/c/platform/android/115), GUI options include:

- **Jetpack Compose** (recommended) - Native Android UI, idiomatic for Android
- **Skip.tools** - Transpiles SwiftUI to Compose (production-ready, third-party)
- **Platform-specific UI** - Swift for logic only, native UI per platform

> **Note:** Skip.tools founders (Marc Prud'hommeaux, Abe White) are also Swift Android Workgroup members, showing the community's collaborative approach to Swift on Android.

### What We Share

```swift
// Shared Swift code (works on both iOS and Android)
struct FoodListing: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let location: Coordinate
    let expiresAt: Date
    let category: Category
}

struct Coordinate: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

enum Category: String, Codable, Sendable {
    case produce, bakery, dairy, prepared, other
}
```

### What Stays Native

| iOS (SwiftUI) | Android (Compose) |
|---------------|-------------------|
| `FoodItemCard` view | `FoodItemCard` composable |
| `GlassButton` component | Material3 `Button` |
| `@Observable` ViewModels | Compose `ViewModel` |
| Core Location | Google Play Location |

---

## Shared Backend (Symlink Architecture)

Foodshare uses a **shared backend repository**:

```
foodshare/
├── foodshare-backend/          ← Source of truth
│   ├── functions/              ← Edge Functions (Deno/TypeScript)
│   ├── migrations/             ← Database migrations
│   └── CLAUDE.md               ← Backend instructions
│
├── foodshare-ios/
│   └── supabase → ../foodshare-backend  (symlink)
│
└── foodshare-android/          ← Future Android app
    └── supabase → ../foodshare-backend  (symlink)
```

**Benefits:**
- Single source of truth for migrations
- Shared Edge Functions
- Consistent RLS policies across platforms

---

## Android App Structure (Proposed)

```
foodshare-android/
├── app/                        # Android app module
│   ├── src/main/
│   │   ├── kotlin/             # Jetpack Compose UI
│   │   │   └── com/foodshare/
│   │   │       ├── ui/         # Composables
│   │   │       ├── viewmodel/  # ViewModels
│   │   │       └── di/         # Dependency injection
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts
│
├── swift-core/                 # Shared Swift package
│   ├── Package.swift
│   └── Sources/
│       └── FoodshareCore/
│           ├── Models/         # Shared domain models
│           ├── Validation/     # Shared validation logic
│           └── Networking/     # Supabase client (optional)
│
├── supabase → ../foodshare-backend  (symlink)
│
└── build.gradle.kts
```

---

## JNI Bridge

Swift code is exposed to Kotlin via a C++ JNI bridge layer:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kotlin (FoodshareCore.kt)                    │
│                    High-level type-safe API                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Kotlin (FoodshareCoreNative.kt)                 │
│                    JNI external declarations                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  C++ (foodshare_jni.cpp)                        │
│    JNI bridge: Java_com_foodshare_* → FoodshareCore_*           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Swift (libFoodshareCore.so)                    │
│                    @_cdecl exported functions                   │
└─────────────────────────────────────────────────────────────────┘
```

### Manual JNI vs swift-java

> **Note:** The Swift team (ktoso) [recommends using swift-java](https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948/3) over manual JNI bindings:
>
> *"Manually writing a binding at first may seem deceptively simple, but can quickly explode in complexity... easy-to-get-wrong cdecl signatures when the functions get more complex."*
>
> [Frameo.com](https://frameo.com) uses swift-java successfully in production.

We currently use manual `@_cdecl` exports for simplicity with our validation-focused use case. Consider migrating to swift-java for:
- More complex APIs with callbacks
- Auto-generated type-safe bindings
- Better maintainability as the API surface grows

### Swift Exports (`@_cdecl`)

```swift
// FoodshareCore/Sources/FoodshareCore/JNI/JNIExports.swift
@_cdecl("FoodshareCore_validateListing")
public func foodshareCore_validateListing(
    title: UnsafePointer<CChar>?,
    description: UnsafePointer<CChar>?,
    quantity: Int32
) -> UnsafeMutablePointer<CChar>? {
    // Returns JSON: {"isValid":true,"errors":[]}
}
```

### C++ JNI Bridge

```cpp
// app/src/main/cpp/foodshare_jni.cpp
extern "C" {
    char* FoodshareCore_validateListing(const char*, const char*, int);
}

JNIEXPORT jstring JNICALL
Java_com_foodshare_swift_FoodshareCoreNative_nativeValidateListing(
    JNIEnv* env, jclass clazz,
    jstring title, jstring description, jint quantity
) {
    const char* titleCStr = env->GetStringUTFChars(title, nullptr);
    const char* descCStr = env->GetStringUTFChars(description, nullptr);
    
    char* result = FoodshareCore_validateListing(titleCStr, descCStr, quantity);
    
    env->ReleaseStringUTFChars(title, titleCStr);
    env->ReleaseStringUTFChars(description, descCStr);
    
    jstring jresult = env->NewStringUTF(result);
    FoodshareCore_freeString(result);
    return jresult;
}
```

### Kotlin API

```kotlin
// High-level API
val result = FoodshareCore.validateListing("Fresh Bread", "Homemade sourdough")
if (!result.isValid) {
    showError(result.errors.firstOrNull())
}
```

### Build Process

```bash
# 1. Cross-compile Swift for Android
cd FoodshareCore
./scripts/build-android.sh all debug
# This automatically copies .so files to foodshare-android/app/src/main/jniLibs/

# 2. Build Android app (CMake builds the JNI bridge automatically)
cd ../foodshare-android
./gradlew assembleDebug
```

The Android build uses CMake to compile the C++ JNI bridge (`foodshare_jni.cpp`) and link it against the pre-built Swift library (`libFoodshareCore.so`).

---

## Data Flow

### Creating a Food Listing

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  User Input  │───►│  Compose UI  │───►│  ViewModel   │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                                               ▼
                                    ┌──────────────────┐
                                    │  Swift Core      │
                                    │  (Validation)    │
                                    └────────┬─────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │  Supabase Client │
                                    │  (Network)       │
                                    └────────┬─────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │  Edge Function   │
                                    │  (Business Logic)│
                                    └────────┬─────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │  PostgreSQL      │
                                    │  (Data + RLS)    │
                                    └──────────────────┘
```

---

## Migration Path

### Phase 1: Setup ✅ Complete
- Document Swift Android Workgroup
- Monitor SDK stability
- Design shared code architecture

### Phase 2: Shared Package ✅ Complete
- FoodshareCore Swift package created
- JNI exports via `@_cdecl`
- Build scripts for Android cross-compilation
- Kotlin JNI wrappers generated

### Phase 3: Android Shell 🔄 In Progress
- Android app with Compose UI
- JNI bridge integration
- Supabase Kotlin client

### Phase 4: Feature Parity ⏳ Pending
- Implement all iOS features in Android
- Share validation and business logic
- Unified testing strategy

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Native UI per platform | SwiftUI not available on Android; Compose is idiomatic |
| Shared Swift domain | Type safety, single source of truth for models |
| Server-side business logic | Reduces client complexity, easier updates |
| Supabase backend | Already implemented, works with any client |
| swift-java for JNI | Official tooling, actively maintained |

---

## Community Considerations

Based on [Swift Forums Android discussions](https://forums.swift.org/c/platform/android/115):

### App Size Impact

| Component | Size Impact |
|-----------|-------------|
| Swift runtime | ~5-10 MB |
| FoundationICU | ~30 MB |
| libc++_shared.so | ~1 MB |
| Your Swift code | Varies |

**Mitigation strategies:**
- Split APKs by architecture (arm64-v8a, x86_64)
- Strip unused ICU locales
- Use release builds with `-Osize` optimization

> **Note:** Per forum discussions, ICU is now namespaced in Foundation, which reduces symbol conflicts with other libraries that bundle ICU.

### BoringSSL Conflicts

If your app uses libraries that bundle BoringSSL (e.g., gRPC, Firebase), you may encounter symbol conflicts with Swift's static linking.

**Solutions:**
- Use dynamic linking where possible
- Coordinate library versions
- Check forum for specific workarounds

### libdispatch Stripping Issue

Per the [community SDK](https://github.com/finagolfin/swift-android-sdk), Android toolchain may strip libdispatch.so and complain about empty DT_HASH. Add to your `build.gradle`:

```kotlin
android {
    packagingOptions {
        jniLibs {
            keepDebugSymbols += "**/libdispatch.so"
        }
    }
}
```

### Push Notifications

Push notifications require platform-native implementation:
- **Android:** Firebase Cloud Messaging (FCM)
- **iOS:** Apple Push Notification Service (APNs)

The notification handling logic can be shared, but the platform integration must be native.

---

## Related Documentation

- [Shared Code Strategy](./SHARED_CODE_STRATEGY.md) - What to share vs. keep native
- [Getting Started](./GETTING_STARTED.md) - SDK setup tutorial
- [Swift Android Workgroup](./SWIFT_ANDROID_WORKGROUP.md) - Official workgroup info
- [iOS Architecture](../architecture/APPSTATE_ARCHITECTURE.md) - iOS app architecture
- [Supabase Backend](../supabase/README.md) - Backend documentation

---

**Last Updated:** December 2025
