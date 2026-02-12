# Swift on Android for Foodshare

> **Status:** Official Swift SDK for Android (6.3 Nightly Preview)

Foodshare Android uses the **official Swift SDK for Android** to share domain logic with the iOS app while maintaining native Jetpack Compose UI.

---

## Documentation Structure

- **[guides/](guides/)** - Getting started, demos, and tutorials
- **[architecture/](architecture/)** - System design and code sharing strategy
- **[technical-reference/](technical-reference/)** - Swift bridge, workgroup notes, community contributions
- **[project-management/](project-management/)** - Project status, phases, and reviews
- **[contributions/](contributions/)** - Community issue reports and forum posts
- **[frameo/](frameo/)** - Frameo framework deep dives

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FoodshareCore (Swift)                        │
│         Domain Models • Validation • Utilities                  │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      iOS App            │     │     Android App         │
│   (Native Swift)        │     │   (Swift via JNI)       │
├─────────────────────────┤     ├─────────────────────────┤
│  import FoodshareCore   │     │  FoodshareCoreNative    │
│  SwiftUI                │     │  Jetpack Compose        │
└─────────────────────────┘     └─────────────────────────┘
```

---

## Quick Start

### Prerequisites

1. **Swift Toolchain** (6.3 snapshot matching SDK)
   ```bash
   curl -L https://swift.org/install.sh | bash
   swiftly install 6.3-snapshot
   swiftly use 6.3-snapshot
   ```

2. **Swift SDK for Android**
   ```bash
   swift sdk install 6.3-snapshot
   swift sdk list  # Verify installation
   ```

3. **Android NDK r27d**
   ```bash
   export ANDROID_NDK_HOME=/path/to/android-ndk-r27d
   ```

### Build

```bash
# 1. Build Swift library for Android
cd FoodshareCore
./scripts/build-android.sh all debug

# 2. Generate Kotlin JNI wrappers
./scripts/generate-jni.sh

# 3. Copy native libraries
cp -r android-libs/* ../foodshare-android/app/src/main/jniLibs/

# 4. Build Android app
cd ../foodshare-android
./gradlew assembleDebug
```

---

## Community Insights

Based on [Swift Forums Android discussions](https://forums.swift.org/c/platform/android/115):

| Topic | Key Insight |
|-------|-------------|
| App Size | FoundationICU adds ~30MB; use stripping strategies |
| GUI Options | SwiftUI not available; use Jetpack Compose |
| swift-java | Use `jextract --mode=jni` for Android (FFM not supported) |
| Testing | Use Termux on physical devices or adb on emulator |
| Debugging | LLDB support in development; use print/logging for now |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [Getting Started](./GETTING_STARTED.md) | SDK installation tutorial |
| [Architecture](./ARCHITECTURE.md) | Cross-platform design |
| [Shared Code Strategy](./SHARED_CODE_STRATEGY.md) | What to share vs. keep native |
| [Swift Android Workgroup](./SWIFT_ANDROID_WORKGROUP.md) | Official workgroup info |
| [Community Contributions](./COMMUNITY_CONTRIBUTIONS.md) | Our PRs, issues, and workarounds |

---

## Resources

| Resource | Link |
|----------|------|
| Swift SDK Guide | https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html |
| Swift Android Workgroup | https://www.swift.org/android-workgroup/ |
| SDK Announcement | https://www.swift.org/blog/nightly-swift-sdk-for-android/ |
| swift-java (JNI) | https://github.com/swiftlang/swift-java |
| Android NDK | https://developer.android.com/ndk/downloads |
| Swift Downloads | https://www.swift.org/download/ |
| Android Forum | https://forums.swift.org/c/platform/android/115 |
| Example Apps | https://github.com/swiftlang/swift-android-examples |
| Community SDK | https://github.com/finagolfin/swift-android-sdk |
| WWDC25 Session | "Explore Swift and Java interoperability" |

---

**Last Updated:** December 2025  
**Status:** Integrated (6.3 Nightly Preview)
