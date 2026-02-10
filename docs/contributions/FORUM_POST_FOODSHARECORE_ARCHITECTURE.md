# Forum Post: FoodshareCore - Swift Code Sharing Between iOS and Android

**Forum:** [Swift Forums - Android Category](https://forums.swift.org/c/platform/android/115)

---

## Title

Case Study: Sharing Swift Domain Logic Between iOS and Android with FoodshareCore

## Post Content

Hi everyone,

I wanted to share our experience building a cross-platform Swift library that powers both our iOS and Android apps. This might be useful for others exploring Swift on Android.

### Project Overview

**FoodshareCore** is a shared Swift library containing:
- Domain models (User, FoodListing, Message, etc.)
- Validation logic (email, password, input sanitization)
- Utility functions (distance calculation, date formatting)
- Business rules

### Architecture

```
FoodshareCore (Swift Package)
├── Sources/FoodshareCore/
│   ├── Models/           # Codable domain models
│   ├── Validation/       # Input validators
│   └── Utilities/        # Shared helpers
└── Tests/
```

**iOS Integration:**
```swift
import FoodshareCore

let isValid = AuthValidator.validateEmail(email)
```

**Android Integration (via manual JNI):**
```kotlin
// Kotlin external declarations call Swift @_cdecl exports
val isValid = FoodshareCoreNative.nativeValidateEmail(email)
```

### Key Learnings

**1. NSPredicate Unavailability**

We initially used `NSPredicate(format:)` for regex validation (common iOS pattern). This doesn't work on Android/Linux. Solution: use `String.range(of:options:.regularExpression)` instead.

```swift
// ❌ iOS only
NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: string)

// ✅ Cross-platform
string.range(of: pattern, options: .regularExpression) != nil
```

**2. Swift 6 Sendable Challenges**

`DateFormatter` didn't conform to `Sendable` in older Swift versions. This was fixed in [PR #5000](https://github.com/swiftlang/swift-corelibs-foundation/pull/5000) (July 2024).

**Important:** Per [forum feedback from Jon_Shier](https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948/5), DateFormatters are expensive to create. Use cached static instances with locks, not local creation:

```swift
// ❌ BAD - creates formatter every call (causes frame drops!)
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

// ✅ GOOD - reuses static formatter with lock
private static let lock = NSLock()
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

func formatDate(_ date: Date) -> String {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    return Self.dateFormatter.string(from: date)
}
```

**3. JNI Integration**

We use manual JNI with Swift `@_cdecl` exports:

```swift
// Swift - expose with C linkage
@_cdecl("FoodshareCore_validateEmail")
public func foodshareCore_validateEmail(_ email: UnsafePointer<CChar>?) -> Bool {
    guard let email = email else { return false }
    return AuthValidator.validateEmail(String(cString: email))
}
```

```kotlin
// Kotlin - external declaration
external fun nativeValidateEmail(email: String): Boolean
```

Note: [swift-java](https://github.com/swiftlang/swift-java) can auto-generate these bindings, but we wrote them manually for finer control.

**4. Gradle Configuration**

Critical: prevent libdispatch stripping:

```kotlin
packaging {
    jniLibs {
        keepDebugSymbols += "**/*.so"
    }
}
```

### Results

- Shared validation and utility logic between iOS and Android
- Identical validation behavior on both platforms
- Single source of truth for business rules
- Swift tests validate shared logic (run on macOS, compiled for Android)

### Open Questions

1. Any tips for reducing FoundationICU size (~30MB)?
2. Has anyone used swift-java's auto-generated bindings in production vs manual JNI?
3. Best practices for CI/CD with cross-platform Swift builds?

Happy to share more details or answer questions!

---

**Tags:** android, swift-java, cross-platform, case-study

---

## Community Replies

### Reply #2 - marcprux (Marc Prud'hommeaux)

**Questions Asked:**
1. What toolchain/SDK version are you using?
2. What does your `build.gradle` configuration look like?

**Recommendations:**

| Topic | Details |
|-------|---------|
| FoundationICU Size | References ongoing discussions about ICU size (~30MB) - significant for APK size |
| CI/CD | Recommends [Swift Android Action](https://github.com/aspect-build/swift-android-action) for GitHub Actions with official Swift SDK support (nightly-6.3+) |
| Real-world Apps | Asked for App Store links to add to "real-world Swift Android apps" list |

---

### Reply #3 - ktoso (Konrad Malawski, Swift Team)

**Key Feedback:** Strong recommendation to use **swift-java** instead of manual JNI bindings.

> "manually writing a binding at first may seem simple, but can quickly explode in complexity"

> "easy-to-get-wrong cdecl signatures"

**Recommendations:**
- Use swift-java with auto-generated bindings via `swift-java jextract`
- File issues for needed flexibility improvements
- They're working on publishing the Java-side library

---

### Reply #4 - ktoso (Follow-up)

Notes that **@madsodgaard uses swift-java successfully at [Frameo](https://frameo.com)** - a real-world production example worth investigating.

---

### Reply #5 - Jon_Shier

**Key Feedback:** Corrects our DateFormatter advice from the original post.

> **"Please don't do this"** - regarding creating DateFormatters locally/repeatedly.

> "DateFormatters are expensive to create, so if you're worried about thread safety it's better to just wrap the static instance in a lock. Repeated formatter creation is an easy way to get frame drops."

**Corrected Pattern:**

```swift
// ❌ BAD - creates formatter every call (causes frame drops!)
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

// ✅ GOOD - reuses static formatter with lock
private static let lock = NSLock()
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

func formatDate(_ date: Date) -> String {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    return Self.dateFormatter.string(from: date)
}
```

**Status:** Fixed in FoodshareCore - updated 5 files:
- `RelativeDateFormatter.swift` (6 cached formatters)
- `ChatMessage.swift` (2 cached formatters)
- `ChatRoom.swift` (3 cached formatters)
- `PayloadMinimizer.swift` (1 cached formatter)
- `AuthValidator.swift` (1 cached formatter)

---

## Action Items

| Author | Feedback | Status |
|--------|----------|--------|
| marcprux | Toolchain questions, CI/CD recommendations | Pending reply |
| ktoso | Use swift-java, not manual JNI | Acknowledged |
| ktoso | Frameo uses swift-java in production | Noted |
| Jon_Shier | DateFormatter performance issue | **Fixed** |

---

## Draft Reply (Ready to Post)

**Post this as a single reply to the thread:**

---

Thanks everyone for the valuable feedback!

**@Jon_Shier** - Great catch on the DateFormatter performance issue. You're absolutely right - we had formatters being created in computed properties that get called during list scrolling. Fixed all instances to use static cached formatters with `NSLock`. Appreciate the guidance!

**@ktoso** - Thanks for the swift-java recommendation. We started with manual `@_cdecl` for our simple validation functions, but your point about complexity explosion is well taken. We'll evaluate migrating as our API surface grows, and will definitely file issues if we hit limitations. Good to know Frameo is using it successfully in production!

**@marcprux** - We're using Swift 6.3 nightly snapshot with the official SDK. Thanks for the GitHub Action recommendation - we'll integrate that into our CI. Regarding app links: we're still in development, but happy to share once we're on the stores!

Updated our docs with all the learnings:
- DateFormatter: use cached static instances with locks (not local creation)
- swift-java: recommended for complex APIs, manual JNI okay for simple validation
- CI/CD: Swift Android Action for GitHub
- ICU size: following the discussion thread

---

**Status:** ⏳ Ready to post manually at https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948

---

**Thread URL:** https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948

**Last Updated:** January 2026
