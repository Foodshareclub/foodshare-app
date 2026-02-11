# 🚀 Ship to Google Play Store - NOW

## Option 1: Automated via CI/CD (Recommended)

### Prerequisites
1. Add GitHub secrets at: `Settings > Secrets and variables > Actions`

```bash
SUPABASE_URL=https://api.foodshare.club
SUPABASE_ANON_KEY=<your-key>
SENTRY_DSN=<your-dsn>
KEYSTORE_PASSWORD=<password>
KEY_ALIAS=foodshare
KEY_PASSWORD=<key-password>
PLAY_STORE_SERVICE_ACCOUNT=<json-content>
```

### Deploy
```bash
# Create release - CI/CD will build and deploy automatically
gh release create v3.0.3 --title "FoodShare Android v3.0.3" --generate-notes
```

**Done!** GitHub Actions will:
- Build release AAB
- Sign with release key
- Upload to Play Store
- Start rollout

---

## Option 2: Manual Upload (Quick)

### Step 1: Build Release AAB
```bash
# Set signing variables
export KEYSTORE_FILE=release.keystore
export KEYSTORE_PASSWORD=your_password
export KEY_ALIAS=foodshare
export KEY_PASSWORD=your_key_password

# Build
./gradlew bundleRelease
```

### Step 2: Upload to Play Store

**Via Console:**
1. Go to https://play.google.com/console
2. Select FoodShare app
3. Release > Production > Create new release
4. Upload: `app/build/outputs/bundle/release/app-release.aab`
5. Add release notes
6. Review and rollout

**Via Command Line:**
```bash
# Install bundletool
brew install bundletool

# Upload
bundletool upload \
  --bundle=app/build/outputs/bundle/release/app-release.aab \
  --package-name=com.foodshare
```

---

## Option 3: Build APK for Testing

```bash
# Build release APK
./gradlew assembleRelease

# Output
ls -lh app/build/outputs/apk/release/app-release.apk

# Install on device
adb install app/build/outputs/apk/release/app-release.apk
```

---

## Pre-Flight Checklist

- [ ] Version updated in `app/build.gradle.kts`
  ```kotlin
  versionCode = 274  // Increment
  versionName = "3.0.3"
  ```
- [ ] Release notes prepared
- [ ] Tested on physical device
- [ ] Keystore ready
- [ ] Play Store listing updated

---

## Release Notes Template

```
What's New in v3.0.3:

✨ New Features
• Real-time profile statistics
• Unread message badges
• Favorites with instant sync
• Relative time display
• Biometric authentication improvements

🐛 Bug Fixes
• Fixed compilation errors
• Improved stability
• Enhanced performance

🔒 Security
• Enhanced biometric storage
• Improved data encryption
```

---

## Rollout Strategy

**Recommended:**
- Day 1: 10% rollout
- Day 2: 25% rollout
- Day 3: 50% rollout
- Day 5: 100% rollout

Monitor crash-free rate > 99.5%

---

## Monitoring

After deployment:
1. **Play Store Console** - Monitor crashes, ANRs, reviews
2. **Sentry** - Real-time crash tracking
3. **Supabase** - API usage and performance

---

## Emergency Rollback

If issues occur:
1. Play Store Console > Halt rollout
2. Fix critical bugs
3. Deploy hotfix: `gh release create v3.0.3.1`

---

## Quick Commands

```bash
# Build release
./gradlew bundleRelease

# Check output
ls -lh app/build/outputs/bundle/release/

# Deploy via CI/CD
gh release create v3.0.3
```

---

🎉 **Ready to ship!**
