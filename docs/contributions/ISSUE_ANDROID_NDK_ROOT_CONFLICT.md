# Feature Request: Support ANDROID_NDK_ROOT as fallback

**Target:** [finagolfin/swift-android-sdk](https://github.com/finagolfin/swift-android-sdk/issues)

---

## Title

feat: Support ANDROID_NDK_ROOT as fallback for ANDROID_NDK_HOME

## Problem

The Swift SDK for Android only checks `ANDROID_NDK_HOME` to locate the NDK. However, Android Studio and Gradle use `ANDROID_NDK_ROOT` as the standard environment variable. This causes friction for developers with existing Android environments.

### Who is affected

- Android Studio users (IDE sets `ANDROID_NDK_ROOT`)
- CI/CD pipelines (GitHub Actions Android setup uses `ANDROID_NDK_ROOT`)
- Teams with mixed Kotlin/Swift Android projects

### Current behavior

```bash
# Developer has Android Studio installed
echo $ANDROID_NDK_ROOT  # /Users/dev/Library/Android/sdk/ndk/27.0.12077973

# Swift SDK fails to find NDK
./setup-android-sdk.sh
# error: ANDROID_NDK_HOME not set
```

## Proposed Solution

Check both environment variables with `ANDROID_NDK_HOME` taking precedence:

```bash
# In setup-android-sdk.sh
ANDROID_NDK="${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}"

if [ -z "$ANDROID_NDK" ]; then
    echo "error: Set ANDROID_NDK_HOME or ANDROID_NDK_ROOT to your NDK path"
    exit 1
fi
```

## Benefits

- Zero friction for existing Android developers
- Works out-of-the-box with Android Studio installations
- CI/CD pipelines work without extra configuration
- Backwards compatible (ANDROID_NDK_HOME still works)
- One-line fix

## Environment

- Swift SDK for Android 6.x
- Android NDK r27+
- Affects macOS and Linux

---

**File at:** https://github.com/finagolfin/swift-android-sdk/issues/new
