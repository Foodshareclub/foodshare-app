# Community Contributions

Tracking our contributions to the Swift Android ecosystem and related open source projects.

---

## Pull Requests

### Open

| Date | Repository | PR | Description | Status | Links |
|------|------------|-----|-------------|--------|-------|
| Jan 2026 | [swiftlang/swift-org-website](https://github.com/swiftlang/swift-org-website) | [#1281](https://github.com/swiftlang/swift-org-website/pull/1281) | Android troubleshooting guide (missing headers, NDK version) | 🟡 Under Review | [CI Run](https://github.com/swiftlang/swift-org-website/actions/runs/20672819995) · [Review](https://github.com/swiftlang/swift-org-website/pull/1281#pullrequestreview-3624503386) |

### Merged

| Date | Repository | PR | Description | Status |
|------|------------|-----|-------------|--------|
| — | — | — | — | — |

---

## Issues Filed

| Date | Repository | Issue | Description | Status | Links |
|------|------------|-------|-------------|--------|-------|
| Jan 2026 | [finagolfin/swift-android-sdk](https://github.com/finagolfin/swift-android-sdk) | [#226](https://github.com/finagolfin/swift-android-sdk/issues/226) | Support ANDROID_NDK_ROOT as fallback for ANDROID_NDK_HOME | ✅ Closed (known upstream issue in swift-driver) | — |
| Jan 2026 | [swiftlang/swift-corelibs-foundation](https://github.com/swiftlang/swift-corelibs-foundation) | [#5345](https://github.com/swiftlang/swift-corelibs-foundation/issues/5345) | NSPredicate(format:) unavailability docs for Android/Linux | 🟡 Open | [Comment](https://github.com/swiftlang/swift-corelibs-foundation/issues/5345#issuecomment-3707551147) |

---

## Issue Comments

Contributions via comments on existing issues:

| Date | Repository | Issue | Contribution | Link | Response |
|------|------------|-------|--------------|------|----------|
| Jan 2026 | [swiftlang/swift-android-examples](https://github.com/swiftlang/swift-android-examples) | [#26](https://github.com/swiftlang/swift-android-examples/issues/26) | Cross-platform architecture with manual JNI, offered to contribute example | [Comment](https://github.com/swiftlang/swift-android-examples/issues/26#issuecomment-3708976715) | ✅ **finagolfin approved**: "a diverse array of examples would be worthwhile" |
| Jan 2026 | [finagolfin/swift-android-sdk](https://github.com/finagolfin/swift-android-sdk) | [#216](https://github.com/finagolfin/swift-android-sdk/issues/216) | Workaround for `--static-swift-stdlib` build failure | [Comment](https://github.com/finagolfin/swift-android-sdk/issues/216#issuecomment-3706927842) | ✅ Acknowledged by maintainer |

### Pending: Cross-Platform Example PR

**Invitation received** from finagolfin (SDK maintainer) on [#26](https://github.com/swiftlang/swift-android-examples/issues/26#issuecomment-3709108377):

> "Sounds good, a diverse array of examples would be worthwhile, similar to the Android NDK's many C/C++ examples."

**Next step:** Create PR with simplified cross-platform example based on FoodshareCore architecture.

---

## Forum Discussions

Contributions to [Swift Forums - Android Category](https://forums.swift.org/c/platform/android/115):

| Date | Topic | Link | Summary |
|------|-------|------|---------|
| Jan 2026 | Case Study: Sharing Swift Domain Logic Between iOS and Android with FoodshareCore | [#83948](https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948) | Cross-platform architecture, JNI integration, lessons learned |

### Forum Feedback Received

| Author | Feedback | Action Taken |
|--------|----------|--------------|
| **Jon_Shier** | DateFormatters are expensive - don't create locally, use locked static instances | ✅ Fixed in FoodshareCore (6 cached formatters) |
| **ktoso** (Swift Team) | Recommends swift-java over manual JNI - warns about complexity explosion | 📝 Noted - evaluating migration |
| **ktoso** | Frameo.com uses swift-java in production successfully | 📝 Reference for production usage |
| **marcprux** | Recommends [Swift Android Action](https://github.com/marketplace/actions/swift-android-action) for CI/CD | 📝 Added to docs |
| **marcprux** | ICU size (~30MB) is ongoing discussion | 📝 Added link to [ICU discussion](https://forums.swift.org/t/android-app-size-and-lib-foundationicu-so/78399) |

---

## Workarounds Discovered

Issues we encountered and solutions we documented:

| Issue | Workaround | Upstream Status |
|-------|------------|-----------------|
| NSPredicate unavailable on Android | Use regex-based validation instead | Issue #5345 open |
| Missing headers (semaphore.h, stddef.h) | Run `setup-android-sdk.sh` after SDK install | PR #1281 under review |
| NDK version mismatch errors | Use NDK r27d or higher | PR #1281 under review |
| `--static-swift-stdlib` build failure | Create symlink for swift_static path | Comment on #216 |
| `ANDROID_NDK_ROOT` env conflict | Unset `ANDROID_NDK_ROOT` when building | ✅ Known upstream issue in swift-driver ([#226 closed](https://github.com/finagolfin/swift-android-sdk/issues/226)) |
| libdispatch stripping in Gradle | Add `keepDebugSymbols` in build.gradle | ✅ Documented in README |
| Swift 6 Sendable issues with DateFormatter | Use cached static formatters with NSLock | ✅ Fixed in PR #5000, performance tip from Jon_Shier |
| Linker flags for missing libraries | Run `setup-android-sdk.sh` to link NDK | ✅ Documented in Getting Started |

---

## How to Contribute

### Filing Issues

| Issue Type | Where to File |
|------------|---------------|
| SDK bugs | [swift/issues](https://github.com/swiftlang/swift/issues) with `Android` label |
| swift-java issues | [swift-java/issues](https://github.com/swiftlang/swift-java/issues) |
| Community SDK | [swift-android-sdk/issues](https://github.com/finagolfin/swift-android-sdk/issues) |
| Documentation | Swift Forums Android category |

### Before Filing

1. Search existing issues
2. Include Swift version, SDK version, NDK version
3. Provide minimal reproduction case
4. Specify host OS (macOS/Linux)

---

## Related Documentation

- [Swift Android Workgroup](./SWIFT_ANDROID_WORKGROUP.md) - Official workgroup info
- [Architecture](./ARCHITECTURE.md) - Our cross-platform design
- [Getting Started](./GETTING_STARTED.md) - Setup guide
- [Contribution Drafts](./contributions/README.md) - Ready-to-submit issues and posts

---

**Last Updated:** January 2026
