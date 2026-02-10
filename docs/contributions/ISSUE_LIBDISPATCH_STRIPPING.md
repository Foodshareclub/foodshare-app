# Issue: libdispatch.so Stripping in Gradle Builds

**Repository:** [finagolfin/swift-android-sdk](https://github.com/finagolfin/swift-android-sdk)

---

## Status: ❌ DO NOT FILE - Already Documented

This issue is **already well-documented** in the swift-android-sdk repository.

### Existing Coverage

| Resource | Link |
|----------|------|
| README documentation | [Building an Android app with Swift](https://github.com/finagolfin/swift-android-sdk#building-an-android-app-with-swift) |
| Original issue | [#67](https://github.com/finagolfin/swift-android-sdk/issues/67) (2022, closed) |
| Recent discussion | [#206](https://github.com/finagolfin/swift-android-sdk/issues/206) (2025, closed) |

### Root Cause (from #67)

The issue occurs because:
1. `patchelf` modifies ELF structure to set rpaths
2. Gradle strips debug symbols during APK packaging
3. Stripping **after** patchelf corrupts the DT_HASH section
4. Order matters: `strip → patchelf = OK`, `patchelf → strip = BROKEN`

### Official Workaround (from README)

```groovy
// build.gradle (Groovy)
packagingOptions {
    doNotStrip "*/arm64-v8a/libdispatch.so"
    doNotStrip "*/armeabi-v7a/libdispatch.so"
    doNotStrip "*/x86_64/libdispatch.so"
}
```

Or using Kotlin DSL:

```kotlin
// build.gradle.kts
android {
    packaging {
        jniLibs {
            keepDebugSymbols.add("**/libdispatch.so")
        }
    }
}
```

### Important Note (from #206)

The `keepDebugSymbols` setting must be in the **app module's** build.gradle, not in library modules. See [Google issue #406020742](https://issuetracker.google.com/issues/406020742).

### Why Not File a New Issue?

1. ✅ Already documented in README
2. ✅ Root cause understood (patchelf + stripping order)
3. ✅ Workaround is simple and effective
4. ✅ Multiple closed issues confirm solution works
5. ❌ A permanent fix would require changes to patchelf or Gradle, not swift-android-sdk

---

**Research Date:** January 2026
