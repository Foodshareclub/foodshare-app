# CI/CD Setup Guide

## GitHub Actions Secrets

Add these secrets to your GitHub repository:

### Required Secrets

1. **SUPABASE_URL**
   - Value: `https://api.foodshare.club`
   - Used for: Backend API connection

2. **SUPABASE_ANON_KEY**
   - Value: Your Supabase anonymous key
   - Used for: Client authentication

3. **SENTRY_DSN** (Optional)
   - Value: Your Sentry DSN
   - Used for: Crash reporting

### Release Signing (Required for production)

4. **KEYSTORE_PASSWORD**
   - Your keystore password

5. **KEY_ALIAS**
   - Your signing key alias

6. **KEY_PASSWORD**
   - Your key password

7. **PLAY_STORE_SERVICE_ACCOUNT**
   - Google Play Console service account JSON
   - Used for: Automated Play Store deployment

## Setup Steps

### 1. Add Secrets to GitHub

```bash
# Navigate to your repo
# Settings > Secrets and variables > Actions > New repository secret
```

### 2. Create Keystore (First time only)

```bash
keytool -genkey -v -keystore foodshare-release.keystore \
  -alias foodshare -keyalg RSA -keysize 2048 -validity 10000
```

### 3. Configure Signing in build.gradle.kts

Add to `app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_FILE") ?: "release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ... existing config
        }
    }
}
```

### 4. Google Play Service Account

1. Go to Google Play Console
2. Setup > API access
3. Create service account
4. Download JSON key
5. Add as `PLAY_STORE_SERVICE_ACCOUNT` secret

## Workflow Triggers

### Pull Requests
- Builds debug APK
- Runs tests
- Uploads artifact for review

### Push to main
- Builds release APK
- Runs tests
- Uploads signed APK

### Release Created
- Builds release AAB
- Deploys to Play Store production track

## Manual Deployment

### Build Release Locally

```bash
# Set environment variables
export KEYSTORE_PASSWORD=your_password
export KEY_ALIAS=foodshare
export KEY_PASSWORD=your_key_password

# Build release
./gradlew assembleRelease

# Output: app/build/outputs/apk/release/app-release.apk
```

### Build AAB for Play Store

```bash
./gradlew bundleRelease

# Output: app/build/outputs/bundle/release/app-release.aab
```

### Upload to Play Store

```bash
# Using bundletool
bundletool upload \
  --bundle=app/build/outputs/bundle/release/app-release.aab \
  --package-name=com.foodshare
```

## Monitoring

### Build Status
- Check Actions tab in GitHub
- View logs for each step
- Download artifacts from successful builds

### Deployment Status
- Google Play Console > Release management
- View rollout percentage
- Monitor crash reports

## Troubleshooting

### Swift SDK Installation Fails
```bash
# CI will retry with fallback
# Or skip Swift build: skipNativeBuild=true
```

### Signing Fails
```bash
# Verify secrets are set correctly
# Check keystore file exists
# Verify passwords match
```

### Play Store Upload Fails
```bash
# Check service account permissions
# Verify package name matches
# Ensure version code is incremented
```

## Version Management

Update version in `app/build.gradle.kts`:

```kotlin
defaultConfig {
    versionCode = 274  // Increment for each release
    versionName = "3.0.3"
}
```

## Release Checklist

- [ ] Update version code and name
- [ ] Update CHANGELOG.md
- [ ] Run tests locally: `./gradlew test`
- [ ] Build release locally: `./gradlew assembleRelease`
- [ ] Test on physical device
- [ ] Create GitHub release
- [ ] Monitor CI/CD pipeline
- [ ] Verify Play Store deployment
- [ ] Monitor crash reports

## Rollback

If issues occur:

1. **Play Store Console**
   - Release management > Halt rollout
   - Or rollback to previous version

2. **GitHub**
   - Revert commit
   - Create hotfix release

## Support

- CI/CD issues: Check Actions logs
- Deployment issues: Google Play Console
- Build issues: See QUICK_START.md
