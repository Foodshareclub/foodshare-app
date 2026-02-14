# FoodShare - Skip Fuse App

A unified Swift codebase generating native iOS and Android apps.

## 🚀 Quick Start

```bash
open Project.xcworkspace
```

Select "FoodShare App" scheme and press Run (⌘R).

## ✅ Features (14 files, ~1000 lines)

### Core
- ✅ Authentication (login, signup, sign out)
- ✅ Supabase integration
- ✅ Tab navigation (4 tabs)

### Feed
- ✅ List food items
- ✅ Search & filter
- ✅ Rich cards with images
- ✅ Pull to refresh
- ✅ Like button

### Listings
- ✅ Detail view
- ✅ Create new listings
- ✅ My listings view
- ✅ Status badges

### Profile
- ✅ User info
- ✅ Avatar
- ✅ Edit profile
- ✅ My listings link

### Activity
- ✅ Notifications feed
- ✅ Activity types (like, comment, claim, message, follow)
- ✅ Unread indicators

### Settings
- ✅ Preferences
- ✅ About info
- ✅ Links (privacy, terms)
- ✅ Sign out

## 📦 Tech Stack

- **Skip Fuse** - Swift → iOS + Android
- **SwiftUI** → Jetpack Compose
- **Supabase** - Backend
- **Kingfisher** - Images

## 🏗️ Structure

```
Sources/FoodShare/
├── FoodShareApp.swift
├── Models/
│   ├── Models.swift (User, Listing, Profile)
│   └── Activity.swift
├── Services/
│   └── AuthService.swift
└── Views/
    ├── LoginView.swift
    ├── MainTabView.swift
    ├── ContentView.swift (Feed)
    ├── FoodListingCard.swift
    ├── ListingDetailView.swift
    ├── CreateListingView.swift
    ├── MyListingsView.swift
    ├── ProfileView.swift
    ├── ActivityView.swift
    └── SettingsView.swift
```

## 🎯 One Codebase, Two Platforms

Write Swift once → Get iOS + Android automatically!

- **iOS**: Native SwiftUI
- **Android**: Native Jetpack Compose
- **No runtime overhead**
- **100% code sharing**

## 📱 Run

iOS + Android launch together from Xcode!

## 🚢 Deploy

**iOS**: Archive → TestFlight
**Android**: `./gradlew bundleRelease`

---

Built with [Skip](https://skip.dev) 🚀
