# Swift Android Workgroup

The Swift Android Workgroup is the official body responsible for establishing Swift as a supported platform for Android development.

> **Source:** [swift.org/android-workgroup](https://www.swift.org/android-workgroup/)

---

## Charter and Goals

The workgroup aims to:

1. **Maintain Android support** in the official Swift distribution without requiring external patches
2. **Enhance core packages** like Foundation and Dispatch for Android compatibility
3. **Define supported API levels** and architectures for Android
4. **Establish CI testing** for Android builds
5. **Create debugging support** for Swift on Android (LLDB)
6. **Facilitate Swift-Java bridging** best practices
7. **Advise and assist** with adding Android support to community Swift packages

---

## Members (December 2025)

The workgroup comprises 10 members:

| Member | Forum Handle |
|--------|--------------|
| Abe White | @aabewhite |
| Andrew Druk | @andriydruk |
| Evan Wilde | @etcwilde |
| Finagolfin | @finagolfin |
| Jason Foreman | @threeve |
| Joannis Orlandos | @Joannis_Orlandos |
| Luke Howard | @lukeh |
| Marc Prud'hommeaux | @marcprux |
| Robbert Brandsma | @obbut |
| Saleem Abdulrasool (Chair) | @compnerd |

The Platform Steering Group selects one member as chair, responsible for organizing meetings and coordinating communication.

---

## Meetings

| Detail | Value |
|--------|-------|
| Frequency | Biweekly |
| Day | Wednesdays (odd-numbered weeks) |
| Time | 12:00 PM ET |
| Format | Video call |

### Requesting an Invitation

Community members can request meeting invitations by posting on the Swift Android forum.

---

## Communication

### Forum

Primary discussion occurs on the Swift Android forum:

**https://forums.swift.org/c/platform/android/115**

Topics include:
- SDK releases and announcements
- Technical discussions
- Build integration
- GUI development options
- Cross-platform development strategies

You can also contact the workgroup privately by messaging **@android-workgroup** on the Swift Forums.

### Recent Discussions (December 2025)

Based on [forum activity](https://forums.swift.org/c/platform/android/115):

| Topic | Key Insight |
|-------|-------------|
| Android SDK 6.3 snapshot released | Latest SDK version |
| Android API minimum for Swift SDK | API 28 (Android 9.0) required, 31 replies |
| Swift for Android vs Kotlin Multiplatform | Comparison discussion, 21 replies |
| GSoC 2025: JNI mode for swift-java | New jextract JNI mode for Android |
| Swift GUI toolkits for Android | Compose recommended, Skip available |
| Android app size (FoundationICU) | ~30MB, stripping strategies, 18 replies |
| New Contributors Call | Onboarding for new contributors |
| Workgroup Meeting Notes (Dec 3) | Latest meeting summary |
| Help using Android Studio | Integration tips, 7 replies |
| Introducing Swift4j | Alternative Java interop approach |
| Thoughts on Swift for Android | Community perspectives, 3701 views |
| M3 Mac installation problems | Apple Silicon troubleshooting |
| Filing issues on Android SDK | Where to report bugs |
| SwiftPM to APK without Java/Gradle | Pure Swift Android apps possible |
| AndroidKit SDK release | Community SDK for Android APIs |
| ICU namespaced in Foundation | Reduces symbol conflicts |
| CommandLine.arguments empty | Known issue with workarounds |
| Bundle.module for Android assets | Resource loading patterns |
| Skip native Swift Android integration | Tech preview announced |

---

## How to Participate

### 1. Join the Forum

Create an account on forums.swift.org and subscribe to the Android category.

### 2. Attend Meetings

Post on the forum to request a meeting invitation. Meetings are open to community members.

### 3. Contribute Code

- Submit bug reports and triage issues
- Create pull requests for Android support projects
- Develop Android development tools

### 4. Test and Report

- Test Swift packages on Android
- Report compatibility issues
- Share findings on the forum

---

## Key Projects

### swift-java

Automatic binding generation between Swift and Java for JNI interoperability. GSoC 2025 added a new JNI mode specifically for Android.

**Repository:** https://github.com/swiftlang/swift-java

### Swift SDK for Android

Official SDK bundle containing libraries, headers, and scripts for Android cross-compilation.

**Getting Started:** https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html

### Community SDK (finagolfin)

Maintained by Finagolfin, provides additional Android SDK resources and daily CI builds.

**Repository:** https://github.com/finagolfin/swift-android-sdk

### AndroidKit

Community SDK providing Swift wrappers for Android APIs.

**Status:** Released (check forum for latest)

---

## Vision and Roadmap

A vision document is currently under review at Swift Evolution to guide Android development priorities.

### Project Board

Track major initiatives on the official project board (check forum for current link).

### Priorities (2025-2026)

1. **Stable SDK release** (currently 6.3 nightly preview)
2. **Improved swift-java bindings** for seamless JNI interop
3. **Foundation/Dispatch parity** with other platforms
4. **Official CI infrastructure** for Android builds
5. **Debugging tools** (LLDB on Android)
6. **App size optimization** (FoundationICU is ~30MB)

---

## Code of Conduct

All contributors must adhere to the Swift Code of Conduct:

https://www.swift.org/code-of-conduct/

If community members have concerns about adherence to the code of conduct, they should contact a member of the Swift Core Team.

---

## Resources

| Resource | Link |
|----------|------|
| Workgroup Page | https://www.swift.org/android-workgroup/ |
| Forum | https://forums.swift.org/c/platform/android/115 |
| SDK Announcement | https://www.swift.org/blog/nightly-swift-sdk-for-android/ |
| Getting Started | https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html |
| swift-java | https://github.com/swiftlang/swift-java |
| Community SDK | https://github.com/finagolfin/swift-android-sdk |
| Example Apps | https://github.com/swiftlang/swift-android-examples |
| Swift Package Index (Android filter) | https://swiftpackageindex.com |

---

## New Contributors

The workgroup hosts **New Contributors Calls** to help onboard developers interested in contributing to Swift on Android. Check the forum for announcements.

---

**Last Updated:** December 2025
