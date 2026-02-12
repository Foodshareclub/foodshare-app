# 🚀 Play Store Launch Checklist

## Phase 1: Play Console Setup (Required)

### 1.1 Create App in Play Console
- [ ] Go to [Google Play Console](https://play.google.com/console/)
- [ ] Click **Create app**
- [ ] Fill in:
  - App name: **FoodShare**
  - Default language: **English (United States)**
  - App or game: **App**
  - Free or paid: **Free**
- [ ] Accept declarations
- [ ] Click **Create app**

### 1.2 Set Up App Access
- [ ] Go to **App content** → **App access**
- [ ] Select: **All functionality is available without restrictions**
- [ ] Click **Save**

### 1.3 Privacy Policy (REQUIRED)
- [ ] Create privacy policy (see PRIVACY_POLICY_TEMPLATE.md)
- [ ] Host on: foodshare.club/privacy or GitHub Pages
- [ ] Go to **App content** → **Privacy policy**
- [ ] Enter URL
- [ ] Click **Save**

### 1.4 Data Safety
- [ ] Go to **App content** → **Data safety**
- [ ] Answer questionnaire about data collection:
  - Location data: **Yes** (for nearby listings)
  - Personal info: **Yes** (name, email)
  - Photos: **Yes** (food photos)
  - Messages: **Yes** (chat feature)
- [ ] Specify data sharing and security practices
- [ ] Click **Save**

### 1.5 Content Rating
- [ ] Go to **App content** → **Content rating**
- [ ] Click **Start questionnaire**
- [ ] Select category: **Social**
- [ ] Answer questions (all "No" for violence, etc.)
- [ ] Submit for rating
- [ ] Wait for rating (usually instant)

### 1.6 Target Audience
- [ ] Go to **App content** → **Target audience**
- [ ] Select: **Ages 13+** (or appropriate age)
- [ ] Click **Save**

### 1.7 News Apps (Skip if not applicable)
- [ ] Go to **App content** → **News apps**
- [ ] Select: **No, this is not a news app**
- [ ] Click **Save**

---

## Phase 2: Store Listing

### 2.1 Main Store Listing
- [ ] Go to **Store presence** → **Main store listing**
- [ ] Fill in:
  - **App name**: FoodShare
  - **Short description**: Share food, reduce waste, build community
  - **Full description**: (see STORE_LISTING_TEMPLATE.md)
- [ ] Click **Save**

### 2.2 Screenshots (REQUIRED - minimum 2)
- [ ] Take screenshots (1080x1920 or 1440x2560)
- [ ] Upload at least 2 phone screenshots
- [ ] Optional: Tablet screenshots
- [ ] Optional: Feature graphic (1024x500)

### 2.3 App Icon
- [ ] Verify icon is 512x512 PNG
- [ ] Upload in **Store presence** → **Main store listing**

### 2.4 Categorization
- [ ] Go to **Store presence** → **Store settings**
- [ ] Category: **Social**
- [ ] Tags: food sharing, community, sustainability
- [ ] Click **Save**

---

## Phase 3: App Signing

### 3.1 Upload Signing Key
- [ ] Go to **Release** → **Setup** → **App signing**
- [ ] Choose: **Let Google manage and protect your app signing key**
- [ ] Upload your upload key certificate
- [ ] Click **Save**

### 3.2 Verify Signing
- [ ] Check that app signing is enabled
- [ ] Download upload certificate if needed

---

## Phase 4: Internal Testing (RECOMMENDED)

### 4.1 Create Internal Testing Release
- [ ] Go to **Release** → **Testing** → **Internal testing**
- [ ] Click **Create new release**
- [ ] Upload AAB file
- [ ] Add release notes
- [ ] Click **Review release**
- [ ] Click **Start rollout to Internal testing**

### 4.2 Add Testers
- [ ] Go to **Internal testing** → **Testers**
- [ ] Create email list of testers
- [ ] Add emails (up to 100 for internal testing)
- [ ] Save

### 4.3 Share Testing Link
- [ ] Copy opt-in URL
- [ ] Share with testers
- [ ] Wait for feedback (1-2 weeks recommended)

---

## Phase 5: Production Release

### 5.1 Create Production Release
- [ ] Go to **Release** → **Production**
- [ ] Click **Create new release**
- [ ] Upload AAB file (or promote from testing)
- [ ] Add release notes
- [ ] Set rollout percentage (start with 20%)

### 5.2 Review and Publish
- [ ] Click **Review release**
- [ ] Verify all information
- [ ] Click **Start rollout to Production**

### 5.3 Monitor
- [ ] Check for crashes in Play Console
- [ ] Monitor reviews
- [ ] Gradually increase rollout to 100%

---

## Phase 6: Post-Launch

### 6.1 Set Up Automated Deployment
- [ ] Follow PLAY_STORE_SETUP.md
- [ ] Add service account to GitHub secrets
- [ ] Test automated deployment

### 6.2 Monitor Metrics
- [ ] Install Play Console app
- [ ] Set up alerts for crashes
- [ ] Monitor user acquisition
- [ ] Track retention metrics

### 6.3 Respond to Reviews
- [ ] Reply to user reviews
- [ ] Address common issues
- [ ] Update app based on feedback

---

## Estimated Timeline

- **Play Console Setup**: 2-3 hours
- **Store Listing**: 1-2 hours
- **Screenshots**: 1 hour
- **Internal Testing**: 1-2 weeks
- **Production Review**: 1-3 days (Google review)
- **Total**: 2-3 weeks for safe launch

---

## Quick Start (Minimum Viable Launch)

If you want to launch ASAP:

1. ✅ Complete Play Console setup (Phase 1) - 2 hours
2. ✅ Create basic store listing (Phase 2) - 1 hour
3. ✅ Upload to internal testing (Phase 4) - 30 mins
4. ⏭️ Skip to production after 1 week of testing

---

## Need Help?

- **Play Console Help**: https://support.google.com/googleplay/android-developer
- **Policy Guidelines**: https://play.google.com/about/developer-content-policy/
- **Launch Checklist**: https://developer.android.com/distribute/best-practices/launch/launch-checklist

---

**Next Step**: Start with Phase 1.1 - Create app in Play Console
