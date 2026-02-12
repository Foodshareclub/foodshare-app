# Built with Opus 4.6: FoodShare Android

> Hackathon Submission | Feb 10-16, 2026 | Cerebral Valley x Anthropic

---

## Problem Statement

**Break the Barriers** -- Expert knowledge, essential tools, AI's benefits -- take something powerful that's locked behind expertise, cost, language, or infrastructure and put it in everyone's hands.

---

## TL;DR

**FoodShare Android** is a production-grade Android app built entirely with Claude Code, featuring a first-of-its-kind **Swift-on-Android** architecture that shares 95% of business logic with the iOS app via JNI. Claude Code orchestrated the creation of 19 cross-platform Swift bridges, 37 core modules, and 17 feature screens -- a project that would typically take a team months, completed by one developer with Claude Code.

---

## The Problem

Food waste is a massive global problem. FoodShare connects people with surplus food to those who need it. The iOS app was already live -- but reaching Android users (72% of the global market) required building a companion app without duplicating the entire codebase.

**The challenge:** Share Swift domain logic between iOS and Android while keeping native UI on both platforms. This is bleeding-edge territory -- Swift on Android is still in nightly preview, with minimal production examples.

**Why "Break the Barriers":** Cross-platform code sharing with Swift on Android is locked behind deep systems programming expertise (JNI, cross-compilation, memory management). Claude Code makes this architecture accessible to solo developers, breaking down the barrier between "possible in theory" and "shipped in practice."

---

## What We Built

### FoodShare Android App

A full-featured Android companion app with:

- **17 feature screens** -- Feed, Search, Map, Chat, Profile, Listings, Reviews, Challenges, Forum, Notifications, and more
- **37 core infrastructure modules** -- Offline sync, caching, rate limiting, analytics, gamification, accessibility
- **19 Swift-Kotlin bridges** -- Sharing validation, matching, recommendations, geo-intelligence, image processing, search, and more with the iOS app
- **Liquid Glass design system** -- Custom Material 3 theme with glassmorphism effects
- **Offline-first architecture** -- Room database with delta sync and conflict resolution

### Swift-on-Android Innovation

The real innovation: **FoodshareCore**, a shared Swift package compiled for Android via JNI:

```
iOS App (SwiftUI)           Android App (Jetpack Compose)
       \                          /
        \                        /
         \                      /
    ┌─────────────────────────────┐
    │     FoodshareCore (Swift)   │
    │  Validators, Engines, ML,   │
    │  Sync, Search, Geo, etc.    │
    └─────────────────────────────┘
```

- **Single source of truth** for all business logic
- **19 bridges** migrated to swift-java (official Swift-Java interop)
- **36+ shared unit tests** running on both platforms
- **Community first**: PR to swift-org-website, forum case study, 4 issue contributions

---

## How Claude Code Made This Possible

### The Scale

| Metric | Count |
|--------|-------|
| Kotlin files created | 200+ |
| Swift bridges implemented | 19 |
| Core modules built | 37 |
| Feature screens | 17 |
| Lines of code | ~50,000+ |
| Swift shared tests | 36 |
| Implementation phases | 19 |

### Claude Code Workflow

Claude Code was the primary development tool for the entire project:

1. **Architecture Design** -- Claude Code analyzed the iOS codebase and designed the Android counterpart with clean architecture (MVVM + Clean Architecture)

2. **Swift Bridge Generation** -- Claude Code wrote all 19 Swift-Kotlin JNI bridges, including the migration from manual `@_cdecl` exports to swift-java generated bindings

3. **Cross-Platform Consistency** -- Claude Code ensured domain models, validation rules, and business logic remained identical across platforms by generating both Swift and Kotlin sides

4. **Infrastructure Modules** -- Claude Code built 37 core modules (offline sync, caching, rate limiting, analytics, gamification, accessibility, etc.) following consistent patterns

5. **Community Contributions** -- Claude Code helped draft the Swift Forums case study, file issues, and prepare PR contributions to the Swift ecosystem

### What Makes This Different

This isn't a simple CRUD app or wrapper. Claude Code tackled genuinely hard problems:

- **JNI bridge design** -- Managing memory across Swift/Kotlin via JNI is notoriously error-prone. Claude Code generated safe, leak-free bridges with proper `SwiftArena` lifecycle management.

- **Delta sync algorithm** -- A complete version-based sync engine with conflict resolution, CRDT support, and state machine -- shared across platforms via Swift.

- **ML recommendations** -- Collaborative filtering, content-based ranking, and contextual bandits -- all in shared Swift code.

- **DBSCAN clustering** -- Geographic intelligence with route optimization, geofencing, and hotspot detection.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Kotlin 2.0 + Swift 6.0 |
| UI | Jetpack Compose + Material 3 |
| Shared Core | FoodshareCore (Swift via JNI) |
| Interop | swift-java (official) |
| Backend | Self-hosted Supabase |
| Database | Room (offline) + PostgreSQL (server) |
| DI | Hilt |
| Network | Ktor + supabase-kt |
| Maps | Google Maps Compose + PostGIS |
| Images | Coil |
| Background | WorkManager |

---

## Architecture

### Ultra-Thin Client

```
┌──────────────────────────────────────────────────┐
│              Supabase Backend (Thick)             │
│  PostgreSQL + PostGIS | Edge Functions | Auth     │
│  RLS Policies | Storage | Realtime               │
└──────────────────────┬───────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
┌────────▼────────┐        ┌─────────▼────────┐
│    iOS App      │        │   Android App    │
│   (SwiftUI)     │        │  (Compose)       │
├─────────────────┤        ├──────────────────┤
│  Native UI      │        │  Native UI       │
│  @Observable    │        │  ViewModel       │
├─────────────────┤        ├──────────────────┤
│                 │        │                  │
│  FoodshareCore ◄├────────┼► FoodshareCore   │
│  (direct)       │        │  (via JNI)       │
│                 │        │                  │
└─────────────────┘        └──────────────────┘
```

### Swift Bridge Architecture (swift-java)

```
Kotlin ViewModel
      │
ValidationBridge.kt (swift-java generated classes + SwiftArena)
      │ JNI (auto-generated)
Swift ListingValidator, AuthValidator, etc.
```

---

## Project Structure

```
foodshare-android/
├── app/src/main/kotlin/com/foodshare/
│   ├── swift/              # Swift JNI integration (4 files)
│   ├── core/               # 37 infrastructure modules
│   │   ├── sync/           # Delta sync + conflict resolution
│   │   ├── cache/          # Memory + disk caching
│   │   ├── geo/            # Geolocation + clustering
│   │   ├── search/         # NLP-powered search
│   │   ├── gamification/   # Points, badges, streaks
│   │   ├── accessibility/  # WCAG compliance
│   │   └── ...             # 30+ more modules
│   ├── features/           # 17 feature screens
│   │   ├── feed/           # Main food feed
│   │   ├── map/            # Map view (PostGIS)
│   │   ├── messaging/      # Real-time chat
│   │   ├── create/         # Create listing wizard
│   │   └── ...             # 13 more screens
│   └── ui/theme/           # Liquid Glass design system
│
├── foodshare-core/         # Shared Swift package (symlink)
│   └── Sources/FoodshareCore/
│       ├── Validation/     # Shared validators
│       ├── Sync/           # Delta sync engine
│       ├── Geo/            # Geographic intelligence
│       └── JNI/            # Bridge exports
│
└── supabase/               # Shared backend (symlink)
```

---

## Key Innovations

### 1. Swift-on-Android at Scale

While Swift on Android exists in nightly preview, there are almost no production examples beyond toy apps. FoodShare Android demonstrates:

- **19 production bridges** covering validation, ML, sync, search, geo, and more
- **swift-java migration** from manual JNI to official tooling
- **Cross-compilation** with automated build scripts
- **Real-world workarounds** for SDK edge cases (documented and contributed upstream)

### 2. Community-First Approach

We didn't just build -- we contributed back:

- **PR #1281** to swift-org-website: Android troubleshooting guide
- **Forum case study** on Swift Forums (response from Swift team member ktoso)
- **4 issue contributions** to swift-android-sdk, swift-corelibs-foundation, swift-android-examples
- **Workarounds documented** for 8 known issues

### 3. Claude Code as Force Multiplier

A single developer built what would typically require a team:

- 19 implementation phases completed
- 200+ Kotlin files generated
- 19 Swift bridges with matching JNI exports
- Comprehensive documentation and architecture docs
- Community contributions drafted and submitted

---

## Running the Project

### Prerequisites

- Android Studio Ladybug+
- JDK 17, Android SDK 35
- Swift 6.0+ with Android SDK

### Quick Start

```bash
git clone https://github.com/Foodshareclub/foodshare-android.git
cd foodshare-android

# Set up Supabase credentials
echo "SUPABASE_URL=https://api.foodshare.club" > local.properties
echo "SUPABASE_ANON_KEY=your-key" >> local.properties

# Build Swift for Android
./gradlew buildSwiftRelease

# Build and run
./gradlew installDebug
```

---

## Links

| Resource | URL |
|----------|-----|
| Android Repo | https://github.com/Foodshareclub/foodshare-android |
| iOS Repo | https://github.com/Foodshareclub/foodshare-ios |
| Web App | https://github.com/Foodshareclub/foodshare |
| Forum Case Study | https://forums.swift.org/t/case-study-sharing-swift-domain-logic-between-ios-and-android-with-foodsharecore/83948 |
| PR to swift-org | https://github.com/swiftlang/swift-org-website/pull/1281 |

---

## Team

**Tarlan (organicnz)** -- Solo developer
Built with Claude Code (Opus 4.6)

---

## Judging Alignment

| Criteria | Weight | How We Address It |
|----------|--------|-------------------|
| **Impact** | 25% | Solves real food waste problem; brings Android users (72% of market) to the platform; advances Swift-on-Android ecosystem with community contributions |
| **Opus 4.6 Use** | 25% | Claude Code designed the architecture, generated all 19 JNI bridges, built 37 modules, drafted community PRs -- went far beyond basic code generation |
| **Depth & Execution** | 20% | 19 implementation phases; migrated from manual JNI to swift-java; delta sync with CRDTs; ML recommendations; DBSCAN clustering -- genuine engineering depth |
| **Demo** | 30% | Working app with live Supabase backend; real-time validation, search, maps, chat; code walkthrough showing shared Swift core |

---

## Submission Checklist

- [ ] 3-minute demo video (YouTube/Loom)
- [ ] GitHub repository link (open source)
- [ ] Written summary (100-200 words)
- [ ] Deadline: Feb 16, 3:00 PM EST

### Written Summary (for submission)

FoodShare Android is a full-featured food-sharing app built entirely with Claude Code during the hackathon. It pioneers **Swift-on-Android** at production scale -- sharing 95% of business logic with the existing iOS app through 19 cross-platform Swift bridges compiled via JNI.

Claude Code served as a true development partner: designing the MVVM + Clean Architecture, generating all Swift-Kotlin JNI bridges (including migration to the official swift-java tooling), building 37 core infrastructure modules, and drafting community contributions to the Swift ecosystem. The result is 17 feature screens, offline-first sync with CRDTs, ML-powered recommendations, NLP search, PostGIS-backed maps, and a custom Liquid Glass design system.

This project demonstrates that Claude Code can make bleeding-edge cross-platform architectures accessible to solo developers, turning what would be a multi-month team effort into a hackathon-achievable reality.

---

## Prizes

| Prize | Award |
|-------|-------|
| 1st Place | $50,000 API Credits |
| 2nd Place | $30,000 API Credits |
| 3rd Place | $10,000 API Credits |
| Most Creative Opus 4.6 Exploration | $5,000 API Credits |
| The "Keep Thinking" Prize | $5,000 API Credits |

**Target prizes:** 1st Place + Most Creative Opus 4.6 Exploration (Swift-on-Android is an unexpected capability showcase)

---

*Built with Opus 4.6 | Cerebral Valley x Anthropic Hackathon | February 2026*
