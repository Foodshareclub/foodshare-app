# FoodShare Deployment Guide

## Prerequisites

### iOS
- Xcode 16.2+
- Apple Developer Account ($99/year)
- App Store Connect access
- Provisioning profiles
- Distribution certificate

### Android
- Android Studio
- Google Play Console account ($25 one-time)
- Signing keystore
- Service account JSON key

---

## Environment Setup

### 1. Configure Secrets

Create `foodshare-android/Skip.env.local`:
```bash
SUPABASE_URL=https://api.foodshare.club
SUPABASE_KEY=your_public_key_here
```

### 2. iOS Signing

In Xcode:
1. Select FoodShare target
2. Signing & Capabilities
3. Team: Select your team
4. Bundle ID: club.foodshare.app

### 3. Android Signing

Create `foodshare-android/Android/app/keystore.properties`:
```properties
storeFile=../release.keystore
storePassword=your_store_password
keyAlias=foodshare
keyPassword=your_key_password
```

Generate keystore:
```bash
keytool -genkey -v -keystore release.keystore \
  -alias foodshare -keyalg RSA -keysize 2048 -validity 10000
```

---

## Build for Release

### iOS

#### 1. Archive
```bash
cd foodshare-android/Darwin
xcodebuild -workspace ../Project.xcworkspace \
  -scheme FoodShare \
  -configuration Release \
  -archivePath build/FoodShare.xcarchive \
  archive
```

#### 2. Export IPA
```bash
xcodebuild -exportArchive \
  -archivePath build/FoodShare.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist
```

#### 3. Upload to TestFlight
```bash
xcrun altool --upload-app \
  -f build/FoodShare.ipa \
  -u your@email.com \
  -p @keychain:AC_PASSWORD
```

Or use Fastlane:
```bash
fastlane beta
```

### Android

#### 1. Build AAB
```bash
cd foodshare-android/Android
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

#### 2. Upload to Play Console
- Go to https://play.google.com/console
- Select FoodShare app
- Release → Production
- Upload AAB
- Fill out release notes
- Submit for review

Or use Fastlane:
```bash
fastlane internal  # Internal testing
fastlane beta      # Open testing
fastlane production # Production release
```

---

## Fastlane Setup

### iOS (Darwin/fastlane/Fastfile)
```ruby
lane :beta do
  build_app(
    workspace: "../Project.xcworkspace",
    scheme: "FoodShare"
  )
  upload_to_testflight
end
```

### Android (Android/fastlane/Fastfile)
```ruby
lane :internal do
  gradle(task: "bundle", build_type: "Release")
  upload_to_play_store(
    track: "internal",
    aab: "app/build/outputs/bundle/release/app-release.aab"
  )
end
```

---

## Version Management

### Update Version

Edit `Skip.env`:
```bash
MARKETING_VERSION = 0.0.2
CURRENT_PROJECT_VERSION = 2
```

This updates both iOS and Android automatically.

---

## CI/CD with GitHub Actions

### Setup Secrets

In GitHub repo settings → Secrets:

**iOS:**
- `FASTLANE_USER` - Apple ID
- `FASTLANE_PASSWORD` - App-specific password
- `MATCH_PASSWORD` - Certificate password

**Android:**
- `PLAY_STORE_JSON_KEY` - Service account JSON
- `KEYSTORE_PASSWORD` - Keystore password
- `KEY_PASSWORD` - Key password

### Workflow

`.github/workflows/ci.yml` already configured:
- Builds on every push
- Runs tests
- Deploys to TestFlight/Play Store on main branch

---

## Monitoring

### Crash Reporting

Add Sentry:
```swift
import Sentry

SentrySDK.start { options in
    options.dsn = "your_dsn"
}
```

### Analytics

Add Firebase:
```swift
import FirebaseAnalytics

Analytics.logEvent("listing_viewed", parameters: ["id": listingId])
```

---

## Rollback Procedure

### iOS
1. Go to App Store Connect
2. Select previous version
3. Submit for review

### Android
1. Go to Play Console
2. Release → Manage releases
3. Promote previous version

---

## Troubleshooting

### Build Fails
```bash
# Clean build
cd foodshare-android
rm -rf .build
swift build
```

### Signing Issues (iOS)
```bash
# Reset certificates
fastlane match nuke development
fastlane match nuke distribution
fastlane match development
fastlane match appstore
```

### Gradle Issues (Android)
```bash
cd Android
./gradlew clean
./gradlew assembleRelease
```

---

## Release Checklist

### Pre-Release
- [ ] Version bumped
- [ ] Changelog updated
- [ ] Tests passing
- [ ] No console warnings
- [ ] Performance tested
- [ ] Beta tested (10+ users)

### App Store Assets
- [ ] App icon (1024x1024)
- [ ] Screenshots (all sizes)
- [ ] App preview video
- [ ] Description
- [ ] Keywords
- [ ] Privacy policy URL
- [ ] Support URL

### Play Store Assets
- [ ] Feature graphic (1024x500)
- [ ] Screenshots (phone + tablet)
- [ ] App icon (512x512)
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Privacy policy URL

### Post-Release
- [ ] Monitor crash reports
- [ ] Monitor reviews
- [ ] Respond to feedback
- [ ] Track analytics
- [ ] Plan next release

---

## Hotfix Procedure

1. Create hotfix branch
2. Fix critical bug
3. Bump patch version (0.0.1 → 0.0.2)
4. Build & test
5. Deploy immediately
6. Merge to main

---

**Last Updated**: 2026-02-12
**Version**: 1.0.0
