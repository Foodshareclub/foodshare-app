# 🚀 Quick Start Guide - FoodShare Android

## Prerequisites

- Android Studio Ladybug or later
- JDK 21
- Android SDK 35
- Swift 6.0+ with Android SDK (for Swift core)

## Setup (5 minutes)

### 1. Clone & Configure

```bash
cd foodshare-android
cp local.properties.template local.properties
```

### 2. Add Supabase Credentials

Edit `local.properties`:

```properties
SUPABASE_URL=https://api.foodshare.club
SUPABASE_ANON_KEY=your-anon-key-here
SENTRY_DSN=your-sentry-dsn-here  # Optional
```

### 3. Build Swift Core (Optional)

The precompiled Swift libraries are already included in `app/src/main/jniLibs/`.

To rebuild:

```bash
./gradlew buildSwiftRelease
```

### 4. Build & Run

```bash
# Debug build
./gradlew assembleDebug

# Install to connected device
./gradlew installDebug

# Or open in Android Studio and click Run ▶️
```

## 🎯 What's Working

### ✅ Core Features
- **Authentication:** Login, signup, MFA, biometric unlock
- **Feed:** Browse food listings with real-time updates
- **Messaging:** Chat with unread count badges
- **Challenges:** Community challenges with leaderboards
- **Forum:** Posts, polls, categories, saved posts
- **Profile:** Live stats (conversations, challenges, food saved)
- **Listings:** Create, view, favorite, share
- **Search:** Full-text search with filters
- **Map:** PostGIS-powered location search
- **Settings:** 17+ settings screens

### ✅ Backend Integration
- All Supabase queries implemented
- Real-time subscriptions working
- Offline-first caching with Room
- Rate-limited RPC calls

### ✅ Swift Integration
- Validation logic (ListingValidator, AuthValidator)
- Business rules (MatchingEngine, GamificationEngine)
- Utilities (InputSanitizer, DistanceFormatter)
- JNI + swift-java bridges

## 📱 Testing

### Unit Tests
```bash
./gradlew test
```

### Instrumented Tests
```bash
./gradlew connectedAndroidTest
```

### Manual Testing Checklist

- [ ] Login with email/password
- [ ] Browse feed and view listing details
- [ ] Create a new listing
- [ ] Send a message
- [ ] Check unread badge on Chats tab
- [ ] View profile stats
- [ ] Toggle favorite on a listing
- [ ] Search for listings
- [ ] View map with nearby listings
- [ ] Enable biometric authentication
- [ ] Check help center (email & chat)

## 🐛 Troubleshooting

### Build Fails

```bash
# Clean and rebuild
./gradlew clean
./gradlew assembleDebug
```

### Swift Library Not Found

```bash
# Rebuild Swift core
./gradlew cleanSwift buildSwiftRelease

# Verify libraries exist
ls app/src/main/jniLibs/arm64-v8a/libFoodshareCore.so
ls app/src/main/jniLibs/x86_64/libFoodshareCore.so
```

### Supabase Connection Issues

1. Check `local.properties` has correct URL and key
2. Verify network connectivity
3. Check Supabase dashboard for service status

### Gradle Sync Issues

```bash
# Invalidate caches in Android Studio
File > Invalidate Caches > Invalidate and Restart
```

## 📊 Performance

### Build Times
- **Clean build:** ~1 minute
- **Incremental build:** ~15 seconds
- **Swift rebuild:** ~30 seconds

### App Size
- **Debug APK:** ~45 MB
- **Release APK:** ~25 MB (with ProGuard)
- **AAB:** ~20 MB

### Runtime Performance
- **Cold start:** <2 seconds
- **Feed load:** <500ms (cached)
- **Search:** <300ms
- **Message send:** <200ms

## 🎨 Design System

### Liquid Glass Components

All UI uses the Liquid Glass design system:

```kotlin
// Example usage
GlassCard {
    GlassButton(
        text = "Share Food",
        style = GlassButtonStyle.Primary,
        onClick = { /* ... */ }
    )
}
```

### Theme Customization

Edit `ui/design/tokens/`:
- `LiquidGlassColors.kt` - Color palette
- `LiquidGlassTypography.kt` - Text styles
- `LiquidGlassSpacing.kt` - Spacing scale
- `LiquidGlassAnimations.kt` - Animation curves

## 🔐 Security

### Release Build

```bash
# Generate release APK
./gradlew assembleRelease

# Sign with your keystore
jarsigner -verbose -sigalg SHA256withRSA \
  -digestalg SHA-256 \
  -keystore your-keystore.jks \
  app/build/outputs/apk/release/app-release-unsigned.apk \
  your-key-alias
```

### ProGuard

ProGuard rules are in `app/proguard-rules.pro`. Already configured for:
- Supabase
- Hilt
- Kotlin serialization
- Swift JNI

## 📚 Documentation

- **Architecture:** `docs/ARCHITECTURE.md`
- **Swift Bridge:** `docs/SWIFT_BRIDGE_REFERENCE.md`
- **Getting Started:** `docs/GETTING_STARTED.md`
- **Completion Report:** `COMPLETION_REPORT.md`

## 🤝 Contributing

1. Create a feature branch
2. Make changes
3. Run tests: `./gradlew test`
4. Run lint: `./gradlew lint`
5. Submit PR

## 📞 Support

- **Email:** support@foodshare.club
- **In-app:** Help Center > Contact Support
- **Docs:** `/docs` directory

## 🎉 You're Ready!

The app is production-ready with all features implemented. Happy coding! 🚀

---

**Last Updated:** February 11, 2026  
**Version:** 3.0.2 (versionCode 273)
