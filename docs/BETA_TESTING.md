# FoodShare Beta Testing Guide

## Overview
This guide covers setting up and running a beta testing program for FoodShare.

---

## Beta Testing Platforms

### iOS - TestFlight
- **Capacity**: Up to 10,000 testers
- **Duration**: 90 days per build
- **Requirements**: Apple Developer account

### Android - Play Store Internal Testing
- **Capacity**: Up to 100 testers (internal), unlimited (open)
- **Duration**: No limit
- **Requirements**: Google Play Console account

---

## Setup

### iOS TestFlight

1. **Build and Upload**
```bash
cd foodshare-android/Darwin
fastlane beta
```

2. **Configure in App Store Connect**
- Go to TestFlight tab
- Add test information
- Add what to test notes
- Enable automatic distribution

3. **Invite Testers**
- Internal: Add by email (up to 100)
- External: Create public link or invite by email

4. **Test Information Template**
```
What to Test:
- Sign up and create your profile
- Browse food listings in the Feed
- Create a new listing with photo and location
- Send messages to other users
- Complete a challenge
- Check your impact dashboard

Known Issues:
- Image upload uses URL input (camera coming soon)
- Map view shows list instead of map (MapKit coming soon)

Feedback:
Please report bugs and suggestions to beta@foodshare.club
```

### Android Play Store

1. **Build and Upload**
```bash
cd foodshare-android/Android
./gradlew bundleRelease
```

2. **Upload to Play Console**
- Go to Testing → Internal testing
- Create new release
- Upload AAB
- Add release notes

3. **Create Tester List**
- Add testers by email
- Or create open testing track

4. **Share Link**
- Copy opt-in URL
- Share with testers

---

## Recruiting Testers

### Target Audience
- Food waste advocates
- Community organizers
- Sustainability enthusiasts
- Tech-savvy early adopters
- Local community members

### Recruitment Channels

1. **Social Media**
```
🚀 We're launching FoodShare - an app to share surplus food and reduce waste!

Looking for beta testers to help us improve before launch.

✅ Test new features first
✅ Shape the product
✅ Make an impact

Sign up: [link]
```

2. **Community Groups**
- Local Facebook groups
- Nextdoor
- Reddit (r/zerowaste, r/sustainability)
- Community gardens
- Food banks

3. **Email List**
- Friends and family
- Professional network
- Existing contacts

4. **In-Person**
- Community events
- Farmers markets
- University campuses

### Tester Requirements
- iOS 17+ or Android 8+
- Active for 2+ weeks
- Provide feedback
- Report bugs

---

## Feedback Collection

### In-App Feedback
Add feedback button to settings:
```swift
Button("Send Feedback") {
    if let url = URL(string: "mailto:beta@foodshare.club?subject=FoodShare Beta Feedback") {
        UIApplication.shared.open(url)
    }
}
```

### Survey (Week 1)
```
1. How easy was it to sign up? (1-5)
2. How intuitive is the app? (1-5)
3. What feature do you use most?
4. What feature is missing?
5. Any bugs or issues?
6. Would you recommend to a friend? (1-10)
7. Additional comments
```

### Survey (Week 2)
```
1. How often do you use the app?
2. Have you created a listing? Why/why not?
3. Have you claimed food? Why/why not?
4. How's the messaging experience?
5. What would make you use it more?
6. Any improvements since last week?
7. Overall satisfaction (1-10)
```

### Bug Report Template
```
Device: [iPhone 15 / Pixel 8]
OS Version: [iOS 17.2 / Android 14]
App Version: [0.0.1]

Steps to Reproduce:
1. 
2. 
3. 

Expected Behavior:


Actual Behavior:


Screenshots:
[Attach if possible]
```

---

## Testing Checklist

### Core Flows
- [ ] Sign up new account
- [ ] Sign in existing account
- [ ] Create listing
- [ ] Edit listing
- [ ] Delete listing
- [ ] View listing details
- [ ] Add comment
- [ ] Send message
- [ ] Edit profile
- [ ] Join challenge
- [ ] View leaderboard
- [ ] Check impact stats
- [ ] Sign out

### Edge Cases
- [ ] Poor network connection
- [ ] No network connection
- [ ] Empty states (no listings, no messages)
- [ ] Long text in fields
- [ ] Special characters in input
- [ ] Multiple rapid taps
- [ ] Background/foreground transitions
- [ ] Low battery mode

### Devices
- [ ] Latest flagship (iPhone 15, Pixel 8)
- [ ] Mid-range (iPhone 13, Pixel 6)
- [ ] Older device (iPhone 11, Pixel 4)
- [ ] Small screen (iPhone SE)
- [ ] Large screen (iPhone 15 Pro Max)
- [ ] Tablet (iPad, Android tablet)

---

## Metrics to Track

### Engagement
- Daily Active Users (DAU)
- Session length
- Sessions per user
- Retention (Day 1, Day 7, Day 30)

### Feature Usage
- Listings created
- Listings claimed
- Messages sent
- Comments posted
- Challenges joined
- Profile views

### Performance
- Crash rate
- App startup time
- API response times
- Error rates

### Feedback
- Bug reports
- Feature requests
- Survey responses
- App store ratings

---

## Communication

### Welcome Email
```
Subject: Welcome to FoodShare Beta! 🎉

Hi [Name],

Thanks for joining the FoodShare beta program!

GETTING STARTED:
1. Download TestFlight (iOS) or click the Play Store link (Android)
2. Install FoodShare
3. Sign up and explore

WHAT TO TEST:
- Browse food listings
- Create your own listing
- Message other users
- Complete challenges
- Check your impact

FEEDBACK:
Reply to this email or send feedback to beta@foodshare.club

We're excited to have you on this journey!

The FoodShare Team
```

### Weekly Update
```
Subject: FoodShare Beta Update - Week [N]

Hi Beta Testers!

THIS WEEK:
- Fixed: [Bug fixes]
- Added: [New features]
- Improved: [Enhancements]

COMING NEXT:
- [Upcoming features]

FEEDBACK NEEDED:
- [Specific areas to test]

Thanks for your continued support!
```

### Bug Fix Notification
```
Subject: Bug Fixed - [Issue Description]

Hi [Name],

Good news! The bug you reported has been fixed:

Issue: [Description]
Fix: [What was done]
Available in: Version 0.0.2

Update your app to get the fix.

Thanks for reporting!
```

---

## Beta Timeline

### Week 1: Internal Testing
- Team members only
- Fix critical bugs
- Verify core functionality

### Week 2: Friends & Family
- 10-20 testers
- Test onboarding
- Gather initial feedback

### Week 3-4: Expanded Beta
- 50-100 testers
- Test at scale
- Monitor performance
- Iterate on feedback

### Week 5-6: Open Beta (Optional)
- Public TestFlight link
- Unlimited testers
- Final polish
- Prepare for launch

---

## Success Criteria

### Before Launch
- [ ] < 1% crash rate
- [ ] All critical bugs fixed
- [ ] 80%+ positive feedback
- [ ] 50+ active testers
- [ ] 7-day retention > 30%
- [ ] Average session > 5 minutes
- [ ] 100+ listings created
- [ ] 50+ messages sent

---

## Tools

### Analytics
- Firebase Analytics
- Mixpanel
- Amplitude

### Crash Reporting
- Sentry
- Firebase Crashlytics
- Bugsnag

### Feedback
- Google Forms
- Typeform
- UserVoice

### Communication
- Mailchimp (email)
- Slack (tester community)
- Discord (tester community)

---

**Good luck with your beta! 🚀**
