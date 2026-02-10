# swift-java Deep Dive

Technical analysis of the swift-java interoperability tool used by Frameo and recommended by the Swift team.

---

## Overview

**swift-java** is both a library and code generator that enables bidirectional Swift/Java interoperability with automatic, safe, and performant bindings.

**Repository:** [github.com/swiftlang/swift-java](https://github.com/swiftlang/swift-java)

---

## Two Modes of Operation

### 1. FFM Mode (Foreign Function & Memory API)

- **Requirement:** JDK 22+
- **Use Case:** Server-side Java, modern JVMs
- **Memory:** Allocated on Java side

### 2. JNI Mode (Java Native Interface)

- **Requirement:** Any JDK (Android compatible!)
- **Use Case:** Android, older Java versions
- **Memory:** Allocated on Swift side
- **Author:** Mads Odgaard (GSoC 2025)

---

## How jextract Works

### Command

```bash
swift-java jextract \
  --swift-module FoodshareCore \
  --mode jni \
  --output-directory generated/
```

### What Gets Generated

| Swift Construct | Java Output |
|-----------------|-------------|
| `class MyClass` | `public class MyClass` |
| `struct MyStruct` | `public class MyStruct` |
| `func doSomething()` | `public void doSomething()` |
| `var property: String` | `public String getProperty()` |
| `enum MyEnum` | `public enum MyEnum` |
| `protocol MyProtocol` | `public interface MyProtocol` |

### Generated Structure

```
generated/
├── java/
│   └── com/example/
│       ├── MyClass.java          # Wrapper class
│       ├── MyStruct.java         # Wrapper class
│       └── SwiftArena.java       # Memory management
└── swift/
    └── JNIExports.swift          # @_cdecl exports
```

---

## Memory Management: SwiftArena

### Confined Arena (Scoped)

```java
try (var arena = SwiftArena.ofConfined()) {
    MySwiftClass obj = new MySwiftClass(arena);
    obj.doSomething();
} // Memory freed here
```

### Auto Arena (GC-managed)

```java
var arena = SwiftArena.ofAuto();
MySwiftClass obj = new MySwiftClass(arena);
obj.doSomething();
// Memory freed when GC collects
```

---

## Code Generation Example

### Swift Source

```swift
public struct Validator {
    public static func validateEmail(_ email: String) -> Bool {
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    public static func sanitize(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### Generated Java (JNI Mode)

```java
public class Validator {

    public static boolean validateEmail(String email) {
        return nativeValidateEmail(email);
    }

    public static String sanitize(String input) {
        return nativeSanitize(input);
    }

    // Native method declarations
    private static native boolean nativeValidateEmail(String email);
    private static native String nativeSanitize(String input);

    static {
        System.loadLibrary("FoodshareCore");
    }
}
```

### Generated Swift JNI Exports

```swift
@_cdecl("Java_com_example_Validator_nativeValidateEmail")
public func Java_com_example_Validator_nativeValidateEmail(
    _ env: UnsafeMutablePointer<JNIEnv>,
    _ cls: jclass,
    _ email: jstring
) -> jboolean {
    let emailStr = String(jniEnv: env, jstring: email)
    return Validator.validateEmail(emailStr) ? JNI_TRUE : JNI_FALSE
}

@_cdecl("Java_com_example_Validator_nativeSanitize")
public func Java_com_example_Validator_nativeSanitize(
    _ env: UnsafeMutablePointer<JNIEnv>,
    _ cls: jclass,
    _ input: jstring
) -> jstring {
    let inputStr = String(jniEnv: env, jstring: input)
    let result = Validator.sanitize(inputStr)
    return result.toJString(env: env)
}
```

---

## Advanced Features

### Async Function Bridging

```swift
// Swift
public func fetchData() async throws -> Data {
    // ...
}
```

```java
// Generated Java - uses CompletableFuture
public CompletableFuture<byte[]> fetchData() {
    return nativeFetchDataAsync();
}
```

### Protocol Implementation in Java

```swift
// Swift protocol
public protocol DataProvider {
    func getData() -> String
}

public func process(provider: DataProvider) -> String {
    return provider.getData().uppercased()
}
```

```java
// Java can implement Swift protocol!
public class MyProvider implements DataProvider {
    @Override
    public String getData() {
        return "Hello from Java";
    }
}

// Use it
String result = SwiftModule.process(new MyProvider());
// Returns: "HELLO FROM JAVA"
```

---

## Comparison: Manual JNI vs swift-java

### Manual JNI (Current FoodshareCore)

```swift
// Swift - manual @_cdecl
@_cdecl("swift_validate_email")
public func validateEmail(_ emailPtr: UnsafePointer<CChar>) -> Bool {
    let email = String(cString: emailPtr)
    return AuthValidator.validateEmail(email)
}
```

```kotlin
// Kotlin - manual external
external fun nativeValidateEmail(email: String): Boolean

// JNI wrapper needed
private external fun swift_validate_email(email: String): Boolean
```

**Issues:**
- Manual string conversion
- Error-prone cdecl signatures
- No type safety across boundary
- Memory management complexity

### swift-java (Frameo Approach)

```swift
// Swift - just write normal code
public struct AuthValidator {
    public static func validateEmail(_ email: String) -> Bool {
        // ...
    }
}
```

```bash
# Generate everything
swift-java jextract --swift-module FoodshareCore --mode jni
```

```kotlin
// Kotlin - use generated Java class
val isValid = AuthValidator.validateEmail(email)
```

**Benefits:**
- Zero manual JNI code
- Type-safe bindings
- Automatic memory management
- Supports async, protocols, enums

---

## Migration Path: FoodshareCore

### Current Architecture

```
Kotlin → FoodshareCoreNative.kt (manual) → @_cdecl exports → Swift
         (2,567 lines)                      (200+ declarations)
```

### Target Architecture (Frameo-style)

```
Kotlin → Generated Java Classes → Auto JNI → Swift
         (auto-generated)         (swift-java)
```

### Migration Status

| Step | Status | Notes |
|------|--------|-------|
| Install swift-java | ⏳ Ready | Run `./scripts/install-swift-java.sh` |
| Gradle task | ✅ Done | `./gradlew generateJniBindings` |
| Swift types public | ✅ Done | All validators are `public struct` |
| Generate bindings | ⏳ Pending | After swift-java installed |
| Update Kotlin callers | ⏳ Pending | ~30 ViewModels to update |
| Delete manual JNI | ⏳ Pending | 4,600 lines to remove |

### Migration Steps

1. **Install swift-java**
   ```bash
   # From foodshare-core directory
   ./scripts/install-swift-java.sh

   # Or manually:
   git clone https://github.com/swiftlang/swift-java ~/.local/swift-java
   cd ~/.local/swift-java && swift build -c release
   mkdir -p ~/bin && cp .build/release/swift-java ~/bin/
   ```

2. **Generate Bindings**
   ```bash
   # From foodshare-android directory
   ./gradlew generateJniBindings

   # This runs:
   swift-java jextract \
     --swift-module FoodshareCore \
     --mode jni \
     --output-java app/src/main/java/com/foodshare/swift/generated \
     --output-swift foodshare-core/Sources/FoodshareCore/JNI/Generated
   ```

3. **Update Kotlin Code**
   ```kotlin
   // Before (manual - FoodshareCoreNative.kt)
   val resultJson = FoodshareCoreNative.nativeValidateListing(title, desc, qty)
   val result = json.decodeFromString<ValidationResult>(resultJson)

   // After (generated - direct call)
   import com.foodshare.swift.generated.ListingValidator
   import com.foodshare.swift.generated.SwiftArena

   SwiftArena.ofAuto().use { arena ->
       val result = ListingValidator.validate(arena, title, desc, qty)
       if (!result.isValid) { showErrors(result.errors) }
   }
   ```

4. **Remove Manual JNI Code**
   - Delete `FoodshareCoreNative.kt` (2,567 lines)
   - Delete `FoodshareCore.kt` wrapper (2,047 lines)
   - Delete manual `@_cdecl` exports in Swift
   - Keep business logic unchanged

---

## Build Integration

### Gradle Task

```kotlin
// build.gradle.kts
tasks.register<Exec>("generateSwiftJavaBindings") {
    workingDir = file("../foodshare-core")
    commandLine(
        "swift-java", "jextract",
        "--swift-module", "FoodshareCore",
        "--mode", "jni",
        "--output-java", "../foodshare-android/app/src/main/java/com/foodshare/swift/generated"
    )
}

tasks.named("preBuild") {
    dependsOn("generateSwiftJavaBindings")
}
```

---

## Performance Considerations

| Aspect | Manual JNI | swift-java |
|--------|------------|------------|
| Call overhead | Minimal | Minimal (same JNI) |
| String conversion | Manual (error-prone) | Automatic (optimized) |
| Memory management | Manual | SwiftArena (safe) |
| Build time | Faster | Slightly slower (codegen) |
| APK size | Smaller | Slightly larger |

---

## Known Limitations

1. **SwiftUI not available** - UI must be native per platform
2. **Some Foundation APIs missing** - Check compatibility
3. **Nightly builds only** - Not stable release yet (as of Jan 2026)
4. **ICU size** - ~30MB overhead from FoundationICU

---

## Resources

- [swift-java Repository](https://github.com/swiftlang/swift-java)
- [swift-android-examples](https://github.com/swiftlang/swift-android-examples)
- [GSoC 2025: Swift-Java](https://www.swift.org/blog/gsoc-2025-showcase-swift-java/)
- [Swift SDK for Android](https://www.swift.org/blog/nightly-swift-sdk-for-android/)

---

**Last Updated:** January 2026
