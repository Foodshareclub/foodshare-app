# Frameo: Production Swift-Java Case Study

**Company:** Frameo A/S (Aarhus, Denmark)
**Product:** WiFi digital photo frames + companion app
**Key Person:** Mads Odgaard (Tech Lead)
**Relevance:** Real-world production example of swift-java on Android

---

## Company Overview

| | |
|---|---|
| **Founded** | 2015, Aarhus, Denmark |
| **Product** | WiFi digital photo frames |
| **App Function** | Send photos from smartphone to Frameo photo frame |
| **iOS App** | [App Store](https://apps.apple.com/us/app/frameo/id1179744119) |
| **Android App** | [Google Play](https://play.google.com/store/apps/details?id=net.frameo.app) |
| **Website** | [frameo.com](https://www.frameo.com/company/) |

---

## Mads Odgaard

### Background

- **Role:** Tech Lead at Frameo
- **Education:** Computer Science, Aarhus University
- **Focus:** iOS development, programming languages, compilers, cryptography
- **Community:** Active in Server-Side Swift community

### Key Contribution: JNI Support for swift-java

During **Google Summer of Code 2025**, Mads implemented JNI support for the `swift-java jextract` tool under mentor **Konrad Malawski** (Apple/Swift Team).

**Problem Solved:**
> "Previously, this tool only worked using the Foreign Function and Memory API (FFM), which requires JDK 22+, making it unavailable on platforms such as Android."

**Result:** Developers can now use swift-java on Android and older Java versions.

---

## Technical Architecture

### swift-java jextract Tool

The tool generates Java wrapper classes from Swift code:

```bash
swift-java jextract --swift-module MySwiftLibrary --mode jni
```

**What it generates:**
- Each Swift class/struct → Java class
- Swift functions/variables → Java methods
- Native methods implemented via Swift `@_cdecl`

### Memory Management Strategy

| Aspect | FFM Mode | JNI Mode (Mads' contribution) |
|--------|----------|-------------------------------|
| Memory allocation | Java side | Swift side |
| Witness tables | Complex handling | Avoided (simpler) |
| JDK requirement | JDK 22+ | Any JDK (Android compatible) |

### SwiftArena Memory Lifecycle

Two implementations for allocation management:

1. **Confined Arenas** - For try-with-resource scopes
2. **Auto Arenas** - Leverages garbage collection

---

## Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    Android App (Kotlin)                     │
│                   Jetpack Compose UI                        │
└─────────────────────────────────────────────────────────────┘
                              │
                    Generated Java Wrappers
                     (swift-java jextract)
                              │
┌─────────────────────────────────────────────────────────────┐
│                     JNI Bridge Layer                        │
│              (Auto-generated, no manual code)               │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Swift Business Logic                     │
│           Shared with iOS via Swift Package                 │
└─────────────────────────────────────────────────────────────┘
```

### What to Share (Swift)

- Domain models
- Validation logic
- Business rules
- API clients
- Offline logic
- Synchronization layers
- Cryptography (swift-crypto)

### What Stays Platform-Native

- UI (SwiftUI on iOS, Jetpack Compose on Android)
- Platform-specific APIs
- Navigation
- Lifecycle management

---

## Conference Talks

### ServerSide.swift Conference

**Talk:** "Expanding Swift/Java Interoperability"

**Topics Covered:**
1. How FFM and JNI modes differ
2. Building shared Swift libraries
3. Using libraries across Swift, Java (FFM), and Android (JNI)
4. Jextracting entire Swift libraries for Android

### Swift Server Meetup #6 (September 2025)

Online meetup highlighting Swift's expansion to Java and Android interoperability.

---

## Official Examples

From [swiftlang/swift-android-examples](https://github.com/swiftlang/swift-android-examples):

### 1. hello-swift-java (Recommended)

**Structure:**
- `hashing-lib/` - Swift package using swift-crypto for SHA256
- `hashing-app/` - Kotlin Android app with Jetpack Compose

**Key Feature:** Press "Hash" button → Kotlin calls Swift directly → SHA256 computed

### 2. swift-java-weather-app

**Advanced Features:**
- Async function bridging
- Protocol implementation in Java passed to Swift

### 3. hello-cpp-swift

**C++ Integration:**
- Package C++ as artifactbundle
- Expose via swift-java
- Automatic JNI generation

---

## Comparison: Frameo vs FoodshareCore

| Aspect | Frameo | FoodshareCore |
|--------|--------|---------------|
| swift-java version | Full auto-generated | Manual + swift-java |
| JNI mode | Yes (Mads built it!) | Yes |
| Shared logic | Business logic | Validation, models, utilities |
| UI | Native per platform | Native per platform |
| Production | Yes | Yes |

---

## Key Takeaways for FoodshareCore

### 1. Full swift-java Adoption

Frameo uses the complete swift-java toolchain. Consider migrating remaining manual JNI to auto-generated.

```bash
# Generate bindings
swift-java jextract --swift-module FoodshareCore --mode jni
```

### 2. Memory Management

Use `SwiftArena` for lifecycle management instead of manual memory handling.

### 3. Architecture Validation

Frameo validates our pattern:
- Share business logic in Swift
- Keep UI native per platform
- Auto-generate JNI bindings

---

## Resources

### Official

- [swift-java GitHub](https://github.com/swiftlang/swift-java)
- [swift-android-examples](https://github.com/swiftlang/swift-android-examples)
- [Swift SDK for Android Announcement](https://www.swift.org/blog/nightly-swift-sdk-for-android/)
- [GSoC 2025 Showcase: Swift-Java](https://www.swift.org/blog/gsoc-2025-showcase-swift-java/)

### Mads Odgaard

- [ServerSide.swift Speaker Profile](https://www.serversideswift.info/speakers/mads-odgaard/)
- [LinkedIn](https://www.linkedin.com/in/mads-odgaard/)

### Frameo

- [Frameo Company](https://www.frameo.com/company/)
- [iOS App](https://apps.apple.com/us/app/frameo/id1179744119)
- [Android App](https://play.google.com/store/apps/details?id=net.frameo.app)

---

## Action Items

- [ ] Watch Mads Odgaard's ServerSide.swift talk when available
- [ ] Evaluate migrating manual JNI to swift-java jextract
- [ ] Test SwiftArena memory management pattern
- [ ] Compare APK size with full swift-java vs current approach

---

**Last Updated:** January 2026
