# Deep Links & App Links Setup

## Overview

FoodShare supports both custom scheme deep links and Android App Links for seamless navigation.

## Configured Links

### 1. App Links (Verified Web Links)
**Domain:** foodshare.club, www.foodshare.club

**Supported Paths:**
- `https://foodshare.club/listing/{id}` - Open specific listing
- `https://foodshare.club/profile/{id}` - Open user profile
- `https://foodshare.club/chat/{id}` - Open chat conversation
- `https://foodshare.club/forum/{id}` - Open forum post
- `https://foodshare.club/challenge/{id}` - Open challenge
- `https://foodshare.club/auth/*` - OAuth callbacks

### 2. Custom Scheme (Legacy)
**Scheme:** `foodshare://`

**Examples:**
- `foodshare://listing/123`
- `foodshare://profile/456`

### 3. OAuth Callback
**Scheme:** `club.foodshare://auth`

Used for OAuth authentication flows.

---

## Setup Required

### Step 1: Generate App Signing Certificate SHA-256

```bash
# For upload key
keytool -list -v -keystore app/upload-keystore.jks -alias upload

# Or from Play Console
# Go to: Release > Setup > App signing
# Copy SHA-256 certificate fingerprint
```

### Step 2: Create assetlinks.json

Create this file and host at: `https://foodshare.club/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.foodshare",
    "sha256_cert_fingerprints": [
      "YOUR_SHA256_FINGERPRINT_HERE"
    ]
  }
}]
```

**Replace `YOUR_SHA256_FINGERPRINT_HERE` with your actual SHA-256 from Step 1.**

### Step 3: Host assetlinks.json

Upload to your web server:
- URL: `https://foodshare.club/.well-known/assetlinks.json`
- Content-Type: `application/json`
- Must be accessible without redirects
- Must use HTTPS

### Step 4: Verify Setup

```bash
# Test with Google's tool
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://foodshare.club&relation=delegate_permission/common.handle_all_urls

# Or use Android Studio
# Tools > App Links Assistant > Test App Links
```

---

## Testing Deep Links

### Test Custom Scheme
```bash
adb shell am start -W -a android.intent.action.VIEW -d "foodshare://listing/123" com.foodshare
```

### Test App Links
```bash
adb shell am start -W -a android.intent.action.VIEW -d "https://foodshare.club/listing/123" com.foodshare
```

### Test OAuth Callback
```bash
adb shell am start -W -a android.intent.action.VIEW -d "club.foodshare://auth?code=abc123" com.foodshare
```

---

## Play Console Configuration

### Add Domain

1. Go to **Grow** > **Deep links**
2. Click **Add domains**
3. Enter: `foodshare.club`
4. Click **Add**
5. Verify status shows "Verified"

### Check Status

Play Console will show:
- ✅ Domain verified
- ✅ App links configured
- ✅ assetlinks.json found

---

## Implementation in Code

Deep links are handled in `MainActivity.kt`:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // Handle deep link
    intent?.data?.let { uri ->
        handleDeepLink(uri)
    }
}

override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    intent?.data?.let { uri ->
        handleDeepLink(uri)
    }
}

private fun handleDeepLink(uri: Uri) {
    when {
        uri.path?.startsWith("/listing/") == true -> {
            val id = uri.lastPathSegment
            // Navigate to listing
        }
        uri.path?.startsWith("/profile/") == true -> {
            val id = uri.lastPathSegment
            // Navigate to profile
        }
        // ... handle other paths
    }
}
```

---

## Troubleshooting

### Domain Not Verified

**Issue:** Play Console shows "Not verified"

**Solutions:**
1. Check assetlinks.json is accessible
2. Verify SHA-256 fingerprint matches
3. Ensure no redirects on the URL
4. Wait up to 24 hours for verification

### Links Open in Browser

**Issue:** Links open in browser instead of app

**Solutions:**
1. Verify domain in Play Console
2. Check assetlinks.json is correct
3. Ensure app is installed
4. Clear browser defaults: Settings > Apps > Browser > Open by default > Clear defaults

### Custom Scheme Not Working

**Issue:** `foodshare://` links don't work

**Solutions:**
1. Check manifest has correct scheme
2. Verify intent filter is correct
3. Test with adb command
4. Check for conflicting apps

---

## Security Notes

- App Links are verified by Google
- Custom schemes are not verified (less secure)
- Always validate deep link data in your app
- Don't trust user input from deep links
- Use App Links for production, custom schemes for development

---

## Migration from Custom Scheme

If you have existing `foodshare://` links:

1. Keep custom scheme for backward compatibility
2. Update all new links to use `https://foodshare.club/`
3. Both will work simultaneously
4. Gradually phase out custom scheme

---

## Resources

- [Android App Links](https://developer.android.com/training/app-links)
- [Digital Asset Links](https://developers.google.com/digital-asset-links)
- [App Links Assistant](https://developer.android.com/studio/write/app-link-indexing)

---

**Next Steps:**
1. Get SHA-256 fingerprint from Play Console
2. Create assetlinks.json with your fingerprint
3. Host at foodshare.club/.well-known/assetlinks.json
4. Add domain in Play Console
5. Test with adb commands
