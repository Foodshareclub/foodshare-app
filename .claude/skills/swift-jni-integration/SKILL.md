---
name: swift-jni-integration
description: Swift-Java bridge patterns for Foodshare Android. Use when working with FoodshareCore Swift library, JNI bindings, SwiftArena memory management, or cross-compilation.
---

<objective>
Correctly integrate FoodshareCore Swift library with Kotlin Android code using swift-java generated bindings and SwiftArena for memory management.
</objective>

<essential_principles>
## Architecture

```
Kotlin Layer (Android)
  Bridge.kt → swift-java Generated Java Classes → SwiftArena → Swift
```

## Key Files

| File | Purpose |
|------|---------|
| `java/.../swift/generated/*.java` | swift-java generated Java classes (100+) — primary integration point |
| `swift/ErrorModels.kt` | Swift-Java generated Kotlin error wrappers |
| `swift/ListingValidator.kt` | Swift-Java generated Kotlin validator wrapper |
| `swift/Models.kt` | Swift-Java generated Kotlin model wrappers |
| `swift/ValidationResult.kt` | Swift-Java generated Kotlin result wrapper |
| `core/validation/ValidationBridge.kt` | Uses swift-java generated classes |
| `foodshare-core/.../JNI/JNIExports.swift` | `@_cdecl` exports for swift-java |

## swift-java Pattern (Preferred)

All bridges are migrated to swift-java. Use SwiftArena for automatic memory management:

```kotlin
// ValidationBridge uses generated ListingValidator Java class
val result = ValidationBridge.validateListing(title, description, quantity)
if (!result.isValid) {
    _uiState.update { it.copy(errors = result.errors) }
}
```

SwiftKit dependency: `org.swift.swiftkit:swiftkit-core:1.0-SNAPSHOT`

## Migration Status

All bridges are migrated to swift-java:
- ValidationBridge, MatchingBridge, GamificationBridge
- RecommendationBridge, NetworkResilienceBridge, GeoIntelligenceBridge
- ImageProcessorBridge, SearchEngineBridge, LocalizationBridge
- FeatureFlagBridge, FormStateBridge, ErrorBridge, BatchOperationsBridge

## Build Commands

```bash
# Regenerate JNI bindings (when Swift code changes)
./gradlew generateJniBindings

# Build Swift for Android
./gradlew buildSwiftRelease

# Output: app/src/main/jniLibs/{arm64-v8a,x86_64}/libFoodshareCore.so

# Run Swift tests (on host)
./gradlew testSwift

# Clean Swift artifacts
./gradlew cleanSwift
```

## Common Issues

| Error | Fix |
|-------|-----|
| `UnsatisfiedLinkError: dlopen failed` | Run `./gradlew buildSwiftRelease` |
| Native build errors | `./gradlew cleanSwift buildSwiftRelease` |
| Swift SDK not found | `swift sdk install 6.0.3-RELEASE-android-24-0.1` |
</essential_principles>

## Adding a New Swift-Kotlin Bridge

1. **Swift side** - Add `@_cdecl` export in `foodshare-core/Sources/FoodshareCore/JNI/JNIExports.swift`
2. **Generate bindings** - Run `./gradlew generateJniBindings`
3. **Kotlin side** - Create Bridge class using generated Java classes with SwiftArena
4. **Inject via Hilt** - Provide bridge in `AppModule.kt`
5. **Test** - Run `./gradlew testSwift` and `./gradlew test`

<success_criteria>
Swift integration is correct when:
- [ ] New bridges use swift-java (not manual JNI)
- [ ] SwiftArena used for memory management
- [ ] Swift .so files present in jniLibs for both arm64-v8a and x86_64
- [ ] JNI bindings regenerated after Swift changes
- [ ] Swift tests pass (`./gradlew testSwift`)
</success_criteria>
