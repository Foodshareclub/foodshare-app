---
name: android-deployment
description: Build, sign, and deploy Foodshare Android to Google Play Store. Use for release preparation, signing configuration, and Play Store submission.
disable-model-invocation: true
---

<objective>
Every Android deployment should be automated, tested, and predictable. Build signed APKs/AABs, run pre-release checks, and submit to Google Play.
</objective>

<essential_principles>
## Pre-Deployment Checklist (Non-Negotiable)

Before ANY deployment:
- [ ] All unit tests pass (`./gradlew test`)
- [ ] All instrumented tests pass (`./gradlew connectedAndroidTest`)
- [ ] Swift tests pass (`./gradlew testSwift`)
- [ ] No lint warnings (`./gradlew lint`)
- [ ] No hardcoded secrets
- [ ] Supabase migrations applied (backend)
- [ ] Version code and name bumped
- [ ] ProGuard/R8 rules verified

## Build Commands

```bash
# Debug build
./gradlew assembleDebug

# Release build (signed)
./gradlew assembleRelease

# App Bundle for Play Store
./gradlew bundleRelease

# Install on device
./gradlew installDebug
./gradlew installRelease

# Run all checks
./gradlew check
```

## Version Management

Update in `app/build.gradle.kts`:
```kotlin
android {
    defaultConfig {
        versionCode = ???        // Increment for every release
        versionName = "?.?.?"    // Semantic versioning
    }
}
```

Check current version in `app/build.gradle.kts` before bumping.

## Signing Configuration

Release signing uses keystore configured in `keystore.properties` (gitignored):
```properties
storeFile=path/to/keystore.jks
storePassword=***
keyAlias=foodshare
keyPassword=***
```

## Release Workflow

1. **Bump version** - Increment versionCode and versionName
2. **Run full test suite** - `./gradlew test connectedAndroidTest testSwift`
3. **Build release bundle** - `./gradlew bundleRelease`
4. **Verify APK** - Check signing, permissions, size
5. **Upload to Play Console** - Internal testing -> Closed beta -> Production
6. **Tag release** - `git tag -a v3.0.3 -m "Release 3.0.3"`

## Security Checks

```bash
# Check for exposed secrets in code
grep -rn "SUPABASE_ANON_KEY\|api_key\|secret" app/src/main/ --include="*.kt" | grep -v BuildConfig

# Verify ProGuard keeps
./gradlew assembleRelease && unzip -l app/build/outputs/apk/release/*.apk | grep "classes.dex"

# Check APK signature
apksigner verify --print-certs app/build/outputs/apk/release/*.apk
```

## Swift Library Verification

Before release, ensure Swift .so files are current:
```bash
./gradlew cleanSwift buildSwiftRelease
ls -la app/src/main/jniLibs/arm64-v8a/libFoodshareCore.so
ls -la app/src/main/jniLibs/x86_64/libFoodshareCore.so
```
</essential_principles>

<success_criteria>
Deployment is ready when:
- [ ] All tests pass
- [ ] No lint warnings
- [ ] No secrets in codebase
- [ ] Version number incremented
- [ ] Release bundle built and signed
- [ ] Swift libraries up to date
- [ ] Changelog updated
- [ ] Play Store listing current
</success_criteria>
