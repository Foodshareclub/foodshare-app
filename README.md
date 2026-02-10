# Foodshare Android

Android companion app for Foodshare - pioneering Swift-on-Android architecture sharing 95% of business logic with iOS.

## Status

**Version:** 1.0.0  
**Status:** Active Development  
**Min SDK:** 28 (Android 9.0)

## Architecture

**Swift-on-Android** - Shared business logic between iOS and Android:

```
┌─────────────────┐         ┌─────────────────┐
│   iOS (Swift)   │         │ Android (Kotlin)│
│   SwiftUI       │         │ Jetpack Compose │
└────────┬────────┘         └────────┬────────┘
         │                           │
         └──────────┬────────────────┘
                    │
         ┌──────────▼──────────┐
         │  FoodshareCore      │
         │  (Swift Package)    │
         │  • Models           │
         │  • Validation       │
         │  • Utilities        │
         └─────────────────────┘
```

## Tech Stack

- **Language:** Kotlin 2.0 + Swift 6.0
- **UI:** Jetpack Compose + Material 3
- **Shared Core:** Swift Package (via JNI)
- **Backend:** Supabase (supabase-kt)
- **Architecture:** MVVM + Clean Architecture

## Quick Start

### Prerequisites

- Android Studio Ladybug+
- JDK 17, Android SDK 35
- Swift 6.0+ with Android SDK (for building Swift core)

### Setup

1. Clone and setup:
   ```bash
   git clone https://github.com/Foodshareclub/foodshare-android.git
   cd foodshare-android
   ```

2. Create `local.properties`:
   ```properties
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

3. Build Swift core for Android:
   ```bash
   ./gradlew buildSwiftRelease
   ```

4. Open in Android Studio and run

## Project Structure

```
foodshare-android/
├── app/                    # Android app (Kotlin/Compose)
├── foodshare-core/        # Shared Swift package (symlink)
├── supabase/              # Shared backend (symlink)
├── scripts/               # Build scripts
└── docs/                  # Documentation
```

## Shared Code

The `foodshare-core` Swift package is shared with iOS:

- **Models:** FoodItem, UserProfile, Message, Review
- **Validation:** Input sanitization, business rules
- **Utilities:** Distance calculation, formatting

## Documentation

- [CLAUDE.md](CLAUDE.md) - Development guide
- [docs/](docs/) - Architecture, setup, community contributions
- [Swift Bridge Reference](docs/architecture/SWIFT_BRIDGE_REFERENCE.md) - JNI integration

## Build Commands

```bash
./gradlew buildSwiftRelease    # Build Swift for Android
./gradlew installDebug          # Install to device
./gradlew test                  # Run tests
```

## License

Private - All rights reserved
# Test
# Test 1
# Test 2

