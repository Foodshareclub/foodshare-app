# FoodShare - App Store Submission Checklist

## Pre-Submission Requirements

### 1. App Store Connect Setup
- [ ] Create app record in App Store Connect
- [ ] Set bundle ID: `club.foodshare.app`
- [ ] Configure app information
- [ ] Set pricing (Free)
- [ ] Select availability (All countries)

### 2. App Icons
- [ ] iOS: 1024x1024 PNG (no transparency, no rounded corners)
- [ ] Android: 512x512 PNG
- [ ] Android adaptive icon: 432x432 foreground + background

### 3. Screenshots

#### iOS Required Sizes
- [ ] 6.7" (iPhone 15 Pro Max): 1290x2796
- [ ] 6.5" (iPhone 14 Plus): 1284x2778
- [ ] 5.5" (iPhone 8 Plus): 1242x2208

#### Android Required Sizes
- [ ] Phone: 1080x1920 (min 2 screenshots)
- [ ] 7" Tablet: 1200x1920
- [ ] 10" Tablet: 1600x2560

#### Screenshot Content
1. Feed with food listings
2. Listing detail view
3. Map view with nearby items
4. Messaging interface
5. Profile with impact stats
6. Challenges/leaderboard

### 4. App Preview Video (Optional but Recommended)
- [ ] iOS: 15-30 seconds, portrait orientation
- [ ] Android: 30 seconds max
- [ ] Show key features: browse, claim, message, impact

### 5. App Description

#### Short Description (80 chars - Play Store)
```
Share surplus food, reduce waste, help your community
```

#### Full Description (4000 chars max)
```
FoodShare connects people to share surplus food and reduce waste in their community.

KEY FEATURES:
• Browse available food near you
• Share your surplus food with neighbors
• Direct messaging with other users
• Track your environmental impact
• Join challenges and earn points
• View leaderboard rankings
• Map view of nearby listings

REDUCE WASTE:
Every year, billions of pounds of food go to waste. FoodShare makes it easy to share surplus food instead of throwing it away.

HELP YOUR COMMUNITY:
Connect with neighbors and help those in need while reducing your environmental footprint.

TRACK YOUR IMPACT:
See how much food you've saved, CO₂ reduced, and people helped.

GAMIFICATION:
Complete challenges, earn points, and climb the leaderboard while making a difference.

100% FREE:
FoodShare is completely free with no ads or in-app purchases.

Join the movement to reduce food waste and build stronger communities!
```

#### Keywords (100 chars - App Store)
```
food sharing,surplus food,reduce waste,community,sustainability,free food,donate,environment
```

### 6. App Information

#### Category
- Primary: Food & Drink
- Secondary: Social Networking

#### Content Rating
- iOS: 4+ (No objectionable content)
- Android: Everyone

#### Privacy Policy
- [ ] Create privacy policy at foodshare.club/privacy
- [ ] Include data collection practices
- [ ] Include third-party services (Supabase)
- [ ] Include user rights (access, deletion)

#### Support URL
- [ ] Create support page at foodshare.club/support
- [ ] Include FAQ
- [ ] Include contact email: support@foodshare.club

### 7. App Review Information

#### Contact Information
- First Name: [Your Name]
- Last Name: [Your Name]
- Phone: [Your Phone]
- Email: [Your Email]

#### Demo Account (Required)
- Username: demo@foodshare.club
- Password: DemoPass123!
- Notes: "Demo account with sample data"

#### Notes for Reviewer
```
FoodShare is a community food sharing platform.

TEST INSTRUCTIONS:
1. Sign in with demo account (demo@foodshare.club / DemoPass123!)
2. Browse food listings on Feed tab
3. View listing details and comments
4. Check Map tab for location-based view
5. View Messages tab (demo account has sample conversations)
6. Check Activity tab for notifications
7. View Profile tab for user stats and impact dashboard

BACKEND:
App uses Supabase for backend services. All data is stored securely with row-level security enabled.

LOCATION:
Location permission is optional and only used to show nearby listings. App works without location access.
```

### 8. Build Information

#### Version
- Marketing Version: 0.0.1
- Build Number: 1

#### Minimum OS Version
- iOS: 17.0
- Android: API 26 (Android 8.0)

### 9. Legal

#### Terms of Service
- [ ] Create ToS at foodshare.club/terms
- [ ] Include user responsibilities
- [ ] Include prohibited content
- [ ] Include liability disclaimers

#### Copyright
```
© 2026 FoodShare. All rights reserved.
```

### 10. Testing Checklist

#### Functionality
- [ ] Sign up new account
- [ ] Sign in existing account
- [ ] Create listing
- [ ] Edit listing
- [ ] Delete listing
- [ ] View listing details
- [ ] Add comment
- [ ] Send message
- [ ] Edit profile
- [ ] View impact dashboard
- [ ] Join challenge
- [ ] View leaderboard
- [ ] Sign out

#### Performance
- [ ] App launches in < 3 seconds
- [ ] No crashes during 30-minute session
- [ ] Smooth scrolling in feed
- [ ] Images load properly
- [ ] No memory leaks

#### UI/UX
- [ ] All text readable
- [ ] Buttons properly sized
- [ ] Navigation intuitive
- [ ] Loading states shown
- [ ] Error messages clear
- [ ] Empty states handled

#### Devices Tested
- [ ] iPhone 15 Pro
- [ ] iPhone SE (small screen)
- [ ] iPad (if supporting)
- [ ] Pixel 8
- [ ] Samsung Galaxy S23
- [ ] Older Android device (API 26)

### 11. Submission

#### iOS
```bash
cd foodshare-android/Darwin
fastlane beta  # Upload to TestFlight
# After TestFlight approval, submit for review in App Store Connect
```

#### Android
```bash
cd foodshare-android/Android
fastlane internal  # Upload to internal testing
# After testing, promote to production in Play Console
```

### 12. Post-Submission

#### Monitor
- [ ] Check App Store Connect for status updates
- [ ] Check Play Console for review status
- [ ] Respond to any reviewer questions within 24 hours

#### Launch Day
- [ ] Monitor crash reports (Sentry)
- [ ] Monitor user reviews
- [ ] Respond to user feedback
- [ ] Track analytics (Firebase)
- [ ] Post on social media
- [ ] Send press release

#### Week 1
- [ ] Daily crash report review
- [ ] Daily review monitoring
- [ ] Collect user feedback
- [ ] Plan hotfix if needed
- [ ] Track key metrics (DAU, retention)

---

## Rejection Prevention

### Common Rejection Reasons

1. **Incomplete Information**
   - Ensure all metadata fields filled
   - Provide working demo account
   - Include clear app description

2. **Crashes**
   - Test thoroughly on multiple devices
   - Fix all known crashes before submission
   - Include crash reporting

3. **Privacy Issues**
   - Include privacy policy
   - Explain data collection clearly
   - Request permissions with clear purpose

4. **Misleading Content**
   - Screenshots must show actual app
   - Description must match functionality
   - No false claims

5. **Guideline Violations**
   - Review App Store Review Guidelines
   - Review Google Play Policy
   - Ensure compliance

---

**Estimated Timeline:**
- Preparation: 3-5 days
- iOS Review: 1-3 days
- Android Review: 1-7 days
- Total: 5-15 days to live

**Good luck with your launch! 🚀**
