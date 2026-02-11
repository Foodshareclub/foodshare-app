# 📦 Shipping Checklist - v3.0.3

## ✅ Pre-Ship Verification

- [x] Version bumped to 3.0.3 (versionCode: 274)
- [x] Build successful (0 errors)
- [x] Tests passing
- [x] Release notes prepared
- [x] All features implemented
- [x] All critical TODOs resolved
- [x] Documentation complete

## 🚀 Shipping Options

### Option A: Automated (5 minutes)
**Best for:** Production deployment with CI/CD

1. **Add GitHub Secrets** (if not done)
   - Go to: GitHub repo > Settings > Secrets > Actions
   - Add: SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN
   - Add: KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
   - Add: PLAY_STORE_SERVICE_ACCOUNT

2. **Create Release**
   ```bash
   gh release create v3.0.3 \
     --title "FoodShare Android v3.0.3" \
     --notes-file RELEASE_NOTES_v3.0.3.md
   ```

3. **Monitor**
   - GitHub Actions: Build progress
   - Play Store Console: Deployment status

---

### Option B: Manual (10 minutes)
**Best for:** Quick testing or no CI/CD access

1. **Build Release AAB**
   ```bash
   # Skip if no keystore
   ./gradlew bundleRelease -PskipSigning=true
   
   # Or with signing
   export KEYSTORE_PASSWORD=your_password
   export KEY_ALIAS=foodshare
   export KEY_PASSWORD=your_key_password
   ./gradlew bundleRelease
   ```

2. **Upload to Play Store**
   - Go to: https://play.google.com/console
   - Select: FoodShare app
   - Navigate: Release > Production > Create new release
   - Upload: `app/build/outputs/bundle/release/app-release.aab`
   - Add release notes from: `RELEASE_NOTES_v3.0.3.md`
   - Review and start rollout

---

### Option C: Test Build (2 minutes)
**Best for:** Internal testing before Play Store

```bash
# Build debug APK
./gradlew assembleDebug

# Install on device
adb install app/build/outputs/apk/debug/app-debug.apk

# Or build release APK (no signing needed)
./gradlew assembleRelease -PskipSigning=true
```

---

## 📋 Post-Ship Checklist

### Immediate (Day 1)
- [ ] Verify build appears in Play Store Console
- [ ] Check initial rollout percentage (start at 10%)
- [ ] Monitor crash-free rate in Play Store Console
- [ ] Check Sentry for any crashes
- [ ] Monitor user reviews

### Short-term (Days 2-5)
- [ ] Increase rollout: 10% → 25% → 50% → 100%
- [ ] Monitor crash-free rate (target: >99.5%)
- [ ] Respond to user reviews
- [ ] Check API usage in Supabase
- [ ] Monitor performance metrics

### Long-term (Week 1+)
- [ ] Analyze user feedback
- [ ] Plan next release
- [ ] Address any issues
- [ ] Update documentation

---

## 🚨 Emergency Procedures

### If Crash Rate Spikes
1. **Halt rollout** in Play Store Console
2. **Check Sentry** for crash details
3. **Fix critical bugs**
4. **Deploy hotfix**: `gh release create v3.0.3.1`

### If Build Fails
1. **Check GitHub Actions logs**
2. **Verify secrets are set correctly**
3. **Test build locally**: `./gradlew bundleRelease`
4. **Fix issues and retry**

---

## 📊 Success Metrics

Monitor these in Play Store Console:
- **Crash-free rate:** >99.5%
- **ANR rate:** <0.5%
- **Install success rate:** >95%
- **User rating:** Maintain or improve
- **Active users:** Track growth

---

## 🎯 Quick Commands

```bash
# Build release
./gradlew bundleRelease

# Check output
ls -lh app/build/outputs/bundle/release/

# Deploy via CI/CD
gh release create v3.0.3 --notes-file RELEASE_NOTES_v3.0.3.md

# Test locally
./gradlew assembleDebug && adb install app/build/outputs/apk/debug/app-debug.apk
```

---

## 📞 Support

- **Build Issues:** See QUICK_START.md
- **Deploy Issues:** See SHIP_TO_PLAY_STORE.md
- **CI/CD Issues:** See .github/CI_CD_SETUP.md

---

## ✅ Ready to Ship!

**Current Status:**
- Version: 3.0.3 (274)
- Build: SUCCESS
- Tests: PASSING
- Documentation: COMPLETE

**Choose your shipping method above and proceed!**

🚀 **Let's ship it!**
