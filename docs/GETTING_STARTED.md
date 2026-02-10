# Getting Started with Swift on Android

Complete setup tutorial for cross-compiling Swift code to Android.

> **Note:** The Swift SDK for Android is currently in nightly preview (6.3 snapshot as of December 2025). Expect changes.

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS or Linux | macOS 14+ or Ubuntu 22.04+ |
| Xcode (macOS) | 15.0+ (for host toolchain) |
| Android NDK | r27d (required) |
| Disk space | ~10 GB |

---

## Setup Overview

Three components are required:

1. **Host Toolchain** - Swift compiler on your development machine
2. **Swift SDK for Android** - Libraries, headers, and resources for Android targets
3. **Android NDK** - Cross-compilation tools (clang, ld)

> **Important:** The host toolchain and Swift SDK versions must match exactly. This is a common source of errors.

---

## Step 1: Install swiftly

The `swiftly` tool manages Swift toolchain versions. This is the recommended approach per the [official documentation](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).

```bash
# Install swiftly
curl -L https://swift.org/install.sh | bash

# Verify installation
swiftly --version
```

---

## Step 2: Install Host Toolchain

The host toolchain version must **exactly match** the SDK version.

```bash
# Install the 6.3 snapshot (recommended for Android SDK compatibility)
swiftly install 6.3-snapshot

# Or install a specific snapshot
swiftly install 6.3-snapshot-2025-12-14

# Set as active toolchain
swiftly use 6.3-snapshot

# Verify installation
swift --version
```

### macOS Note

On macOS, you must use the OSS toolchain (not Xcode's bundled Swift) for cross-compilation:

```bash
# Find OSS toolchain path
ls /Library/Developer/Toolchains/

# Example path
export TOOLCHAIN=/Library/Developer/Toolchains/swift-6.3-DEVELOPMENT-SNAPSHOT-*.xctoolchain
```

### M1/M2/M3 Mac Users

Per [forum discussions](https://forums.swift.org/c/platform/android/115), Apple Silicon Macs are fully supported. If you encounter installation issues:

1. Ensure Rosetta 2 is installed: `softwareupdate --install-rosetta`
2. Use the arm64 toolchain variant when available
3. Check that `ANDROID_NDK_HOME` points to the correct architecture

---

## Step 3: Install Swift SDK for Android

Download and install the SDK bundle using the built-in `swift sdk` command. Per the [official guide](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html):

```bash
# Install the 6.3 snapshot SDK (recommended)
swift sdk install 6.3-snapshot

# Or install a specific snapshot version
swift sdk install 6.3-snapshot-2025-12-14

# Verify installation
swift sdk list
```

Expected output:
```
aarch64-unknown-linux-android28
x86_64-unknown-linux-android28
```

> **Note:** The SDK is also bundled with the Windows installer if you're developing on Windows.

---

## Step 4: Install Android NDK

The Swift SDK requires NDK version **r27d**.

### macOS

```bash
# Download NDK r27d
curl -O https://dl.google.com/android/repository/android-ndk-r27d-darwin.zip

# Extract
unzip android-ndk-r27d-darwin.zip

# Set environment variable
export ANDROID_NDK_HOME=$PWD/android-ndk-r27d

# Add to shell profile (~/.zshrc or ~/.bashrc)
echo 'export ANDROID_NDK_HOME=$HOME/android-ndk-r27d' >> ~/.zshrc
```

### Linux

```bash
# Download NDK r27d
curl -O https://dl.google.com/android/repository/android-ndk-r27d-linux.zip

# Extract
unzip android-ndk-r27d-linux.zip

# Set environment variable
export ANDROID_NDK_HOME=$PWD/android-ndk-r27d

# Add to shell profile
echo 'export ANDROID_NDK_HOME=$HOME/android-ndk-r27d' >> ~/.bashrc
```

---

## Step 5: Link NDK to SDK

Run the setup script included in the SDK bundle:

```bash
# The setup script is included with the Swift SDK bundle
# It links the NDK to the Swift SDK for cross-compilation

# If ANDROID_NDK_HOME is set, just run:
swift sdk configure android

# Or manually run the setup script:
cd ~/.swiftpm/swift-sdks/swift-6.3-*-android-*.artifactbundle
./setup-android-sdk.sh
```

> **Tip:** If you installed the NDK in a custom location, set `ANDROID_NDK_HOME` before running the setup script.

---

## Step 6: Verify Installation

Create a test project:

```bash
mkdir swift-android-test && cd swift-android-test
swift package init --type executable --name HelloAndroid
```

Edit `Sources/HelloAndroid/main.swift`:

```swift
print("Hello from Swift on Android!")
```

Build for Android:

```bash
# Build for ARM64 (most modern devices)
swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# Build for x86_64 (emulator)
swift build --swift-sdk x86_64-unknown-linux-android28 --static-swift-stdlib
```

---

## Supported Architectures

| Architecture | SDK Target | Use Case |
|--------------|------------|----------|
| ARM64 | `aarch64-unknown-linux-android28` | Physical devices |
| x86_64 | `x86_64-unknown-linux-android28` | Emulator |

**Minimum API Level:** Android 28 (Android 9.0 Pie)

> **Note:** The minimum API level (28) is an active discussion topic in the [Swift Android Forum](https://forums.swift.org/c/platform/android/115). API 28 was chosen to balance modern Android features with device coverage. Lower API levels may be supported in future SDK versions.

---

## Deployment

### Deploy to Device/Emulator

Per the [official documentation](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html):

```bash
# Ensure ADB is available
adb devices

# Push executable to device
adb push .build/aarch64-unknown-linux-android28/debug/HelloAndroid /data/local/tmp/

# Push libc++ shared library (required)
adb push $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so /data/local/tmp/

# Run on device
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=. ./HelloAndroid"
```

Expected output:
```
Hello from Swift on Android!
```

### Building Android Apps

> **Important:** Android applications are typically not deployed as command-line executables. They are assembled into `.apk` archives and launched from the home screen.

To build a full Android app with Swift:

1. Build Swift modules as shared object libraries (`.so`) for each architecture
2. Include the libraries in the app archive under `jniLibs/`
3. Access Swift code from Kotlin/Java through JNI using [swift-java](https://github.com/swiftlang/swift-java)

See the [swift-android-examples](https://github.com/swiftlang/swift-android-examples) repository for complete app examples.

---

## Build Commands Reference

```bash
# Debug build for ARM64
swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# Release build for ARM64
swift build -c release --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# Build with tests
swift build --build-tests --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# macOS: Specify OSS toolchain
swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib \
  --toolchain /Library/Developer/Toolchains/swift-DEVELOPMENT-*.xctoolchain
```

---

## Troubleshooting

### Error: SDK not found

```
error: no Swift SDK 'aarch64-unknown-linux-android28' found
```

**Solution:** Run `swift sdk list` to verify installation. Re-run installation if needed.

### Error: NDK not found

```
error: ANDROID_NDK_HOME environment variable not set
```

**Solution:** Export the NDK path and run the setup script:
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r27d
./setup-android-sdk.sh
```

### Error: Toolchain mismatch

```
error: Swift SDK requires Swift version X.Y.Z but found A.B.C
```

**Solution:** Install the matching toolchain version:
```bash
swiftly install main-snapshot-YYYY-MM-DD
swiftly use main-snapshot-YYYY-MM-DD
```

### Error: Missing libc++_shared.so

```
CANNOT LINK EXECUTABLE: library "libc++_shared.so" not found
```

**Solution:** Push the shared library alongside your executable:
```bash
adb push $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so /data/local/tmp/
```

### Error: dlopen failed / cannot locate symbol

```
dlopen failed: cannot locate symbol "_ZN..."
```

**Solution:** This often indicates NDK version mismatch. Ensure you're using NDK r27d:
```bash
echo $ANDROID_NDK_HOME
# Should point to android-ndk-r27d
```

### Error: CommandLine.arguments empty

Per forum discussions, `CommandLine.arguments` may be empty on Android.

**Solution:** Pass arguments via environment variables or JNI instead:
```swift
// Use environment variables
let value = ProcessInfo.processInfo.environment["MY_ARG"]

// Or pass via JNI from Kotlin
```

### Error: Bundle.module not found

Resource bundles work differently on Android.

**Solution:** Load resources from Android assets instead:
```swift
#if os(Android)
// Load from Android assets directory
#else
let resource = Bundle.module.url(forResource: "data", withExtension: "json")
#endif
```

### macOS: Using Xcode toolchain instead of OSS

Cross-compilation requires the OSS toolchain, not Xcode's bundled Swift.

**Solution:** Specify the toolchain path:
```bash
swift build --swift-sdk aarch64-unknown-linux-android28 \
  --toolchain /Library/Developer/Toolchains/swift-DEVELOPMENT-*.xctoolchain
```

### Android Studio Integration

Per forum discussions, Android Studio doesn't directly support Swift. Workflow:

1. Build Swift library separately using SwiftPM
2. Copy `.so` files to `app/src/main/jniLibs/{arch}/`
3. Add Kotlin JNI wrappers to your Android project
4. Use Gradle to build the final APK

You can automate this with Gradle tasks or external build scripts.

---

## Next Steps

1. Read [Architecture](./ARCHITECTURE.md) for Foodshare cross-platform design
2. Read [Shared Code Strategy](./SHARED_CODE_STRATEGY.md) for code sharing patterns
3. Explore [swift-android-examples](https://github.com/swiftlang/swift-android-examples) for full app examples

---

## Testing Swift Code for Android

### Unit Tests (Host Platform)

Run tests on your development machine:

```bash
# Run tests on macOS/Linux
swift test
```

### Cross-Compiled Tests

Build tests for Android (running them requires device/emulator):

```bash
# Build tests for Android
swift build --build-tests --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

# Push test executable to device
adb push .build/aarch64-unknown-linux-android28/debug/FoodshareCorePackageTests.xctest /data/local/tmp/

# Run tests on device
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=. ./FoodshareCorePackageTests.xctest"
```

### Testing with Termux

Per the [community SDK](https://github.com/finagolfin/swift-android-sdk), you can also test on physical devices using Termux:

```bash
# On Android device with Termux, copy test executables via scp
scp user@host:.build/aarch64-unknown-linux-android28/debug/*.xctest .

# Copy Swift runtime libraries
scp user@host:/path/to/swift-libs/*.so .

# Run tests
LD_LIBRARY_PATH=. ./YourPackageTests.xctest
```

### Debugging

> **Note:** LLDB debugging on Android is a priority for the [Swift Android Workgroup](./SWIFT_ANDROID_WORKGROUP.md) but is still in development.

Current debugging options:
- **Print debugging:** Use `print()` statements and check logcat
- **Logging:** Use `swift-log` for structured logging
- **Unit tests:** Test shared code on host platform first

```bash
# View Swift output in logcat
adb logcat | grep -i swift
```

---

## Resources

| Resource | Link |
|----------|------|
| Official Guide | https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html |
| NDK Downloads | https://developer.android.com/ndk/downloads |
| Swift Downloads | https://www.swift.org/download/ |
| swiftly Tool | https://github.com/swiftlang/swiftly |
| Android Forum | https://forums.swift.org/c/platform/android/115 |
| Example Apps | https://github.com/swiftlang/swift-android-examples |
| swift-java | https://github.com/swiftlang/swift-java |
| Community SDK | https://github.com/finagolfin/swift-android-sdk |
| Skip.tools | https://skip.tools/docs/ |
| GitHub Action | https://github.com/marketplace/actions/swift-android-action |
| ICU Size Discussion | https://forums.swift.org/t/android-app-size-and-lib-foundationicu-so/78399 |

### Learning Resources

- **WWDC25:** "Explore Swift and Java interoperability" session
- **Swift Server Side Meetup:** Talk by Mads Odgaard on swift-java bindings
- **Swift Academy Podcast:** Joannis discussing the Android SDK
- **Swift Package Indexing Podcast:** Android episode
- **SDK Announcement:** https://www.swift.org/blog/nightly-swift-sdk-for-android/

---

## Community Tips & Experiences

Based on discussions from the [Swift Android Forum](https://forums.swift.org/c/platform/android/115):

### App Size Optimization

The `lib_FoundationICU.so` library adds ~30MB to your app. Strategies to reduce size:

- Strip unused locales from ICU data
- Use `--static-swift-stdlib` flag
- Consider release builds with optimization flags
- Split APKs by architecture (arm64-v8a, x86_64)

> **Note:** ICU is now namespaced in Foundation (per forum), which reduces symbol conflicts with other libraries that bundle ICU.

### Pure Swift APKs (No Java/Gradle)

Per forum discussions, it's possible to build APKs without Java, Gradle, or Android Studio using SwiftPM directly. This is an advanced use case - see the forum topic "SwiftPM to apk without Java, gradle and Android Studio" for details.

### Swift vs Kotlin Multiplatform

| Aspect | Swift on Android | Kotlin Multiplatform |
|--------|------------------|---------------------|
| Language | Swift (same as iOS) | Kotlin |
| Tooling maturity | Nightly preview | Production-ready |
| iOS code sharing | Native | Requires Kotlin |
| Android integration | JNI via swift-java | Native |
| Learning curve | Low (if you know Swift) | Medium |

### GUI Development

SwiftUI is **not available** on Android. Options:

1. **Jetpack Compose** (recommended) - Native Android UI, best performance
2. **Skip.tools** - Transpiles SwiftUI to Compose, production-ready
   - Genuinely native output (not a runtime layer)
   - 25%+ of Swift Package Index packages compatible
   - Founded by Swift Android Workgroup members
3. **Platform-specific UI** - Swift for logic, native UI per platform

| Approach | Pros | Cons |
|----------|------|------|
| Jetpack Compose | Native, idiomatic, best docs | Separate UI codebase |
| Skip.tools | Share SwiftUI code | Third-party, learning curve |
| Swift logic only | Maximum flexibility | Most code duplication |

### Swift vs Kotlin Multiplatform

Per forum discussions ("Swift for Android vs Kotlin Multi-platform", 21 replies):

| Aspect | Swift on Android | Kotlin Multiplatform |
|--------|------------------|---------------------|
| Language | Swift (same as iOS) | Kotlin |
| Tooling maturity | Nightly preview | Production-ready |
| iOS code sharing | Native Swift | Requires Kotlin |
| Android integration | JNI via swift-java | Native |
| Learning curve | Low (if you know Swift) | Medium |
| Community size | Growing | Large |
| IDE support | Xcode + Android Studio | Android Studio + Fleet |

**When to choose Swift on Android:**
- You have existing Swift/iOS codebase
- Team expertise is primarily Swift
- You want single-language cross-platform

**When to choose KMP:**
- Starting fresh with no existing code
- Team knows Kotlin well
- Need production-ready tooling today

### CMake Integration

For complex projects, CMake can be used for cross-compilation:

```cmake
# Example CMakeLists.txt for Swift on Android
cmake_minimum_required(VERSION 3.20)
project(MySwiftLib LANGUAGES Swift)

set(CMAKE_Swift_COMPILER_TARGET aarch64-unknown-linux-android28)
add_library(MySwiftLib SHARED Sources/MyLib.swift)
```

### Conditional Package Dependencies

Use SwiftPM conditions for platform-specific dependencies:

```swift
// Package.swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SomePackage", package: "some-package",
                 condition: .when(platforms: [.iOS, .macOS])),
    ]
)
```

### Porting Packages to Android

Per the [community SDK](https://github.com/finagolfin/swift-android-sdk), the most common changes needed:

```swift
// Import the Android overlay when calling Android's C APIs
#if canImport(Android)
import Android
#endif

// Handle opaque FILE struct (Android 7+)
#if os(Android)
typealias FILEPointer = OpaquePointer
#else
typealias FILEPointer = UnsafeMutablePointer<FILE>
#endif
```

### ANDROID_NDK_ROOT Warning

If you have `ANDROID_NDK_ROOT` environment variable set (common on CI), unset it when using the SDK bundle:

```bash
unset ANDROID_NDK_ROOT
swift build --swift-sdk aarch64-unknown-linux-android28
```

---

**Last Updated:** December 2025
