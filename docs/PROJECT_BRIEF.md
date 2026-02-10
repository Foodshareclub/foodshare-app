# FoodShare Android -- Project Brief

> Quick reference for hackathon judges | Problem Statement: **Break the Barriers**

---

## One-Liner

Android food-sharing app built with Claude Code, featuring a pioneering Swift-on-Android architecture that shares 95% of business logic with iOS.

---

## Submission Summary (100-200 words)

FoodShare Android is a full-featured food-sharing app built entirely with Claude Code during the hackathon. It pioneers **Swift-on-Android** at production scale -- sharing 95% of business logic with the existing iOS app through 19 cross-platform Swift bridges compiled via JNI.

Claude Code served as a true development partner: designing the MVVM + Clean Architecture, generating all Swift-Kotlin JNI bridges (including migration to the official swift-java tooling), building 37 core infrastructure modules, and drafting community contributions to the Swift ecosystem. The result is 17 feature screens, offline-first sync with CRDTs, ML-powered recommendations, NLP search, PostGIS-backed maps, and a custom Liquid Glass design system.

This project demonstrates that Claude Code can make bleeding-edge cross-platform architectures accessible to solo developers, turning what would be a multi-month team effort into a hackathon-achievable reality.

---

## By the Numbers

| Metric | Value |
|--------|-------|
| Kotlin files | 200+ |
| Swift bridges | 19 |
| Core modules | 37 |
| Feature screens | 17 |
| Shared Swift tests | 36 |
| Implementation phases | 19 |
| Code sharing with iOS | ~95% of business logic |
| Developer count | 1 (with Claude Code) |

---

## What's Innovative

### 1. Swift on Android at Production Scale

Swift on Android is in nightly preview with almost zero production examples. FoodShare Android demonstrates it works at scale: 19 bridges covering validation, ML, sync, search, geo-intelligence, gamification, accessibility, and more.

### 2. Claude Code as Full Development Partner

Claude Code didn't just autocomplete -- it designed the architecture, generated all JNI bridges, built 37 infrastructure modules with consistent patterns, and drafted community contributions to the Swift ecosystem.

### 3. Community Impact

- PR to swift-org-website (troubleshooting guide)
- Forum case study with Swift team engagement (ktoso)
- 4 issue contributions to Swift Android ecosystem
- 8 workarounds documented and shared

---

## Tech Stack

**Frontend:** Kotlin 2.0, Jetpack Compose, Material 3
**Shared Core:** Swift 6.0 via JNI (swift-java)
**Backend:** Self-hosted Supabase (PostgreSQL, PostGIS, Edge Functions)
**Local:** Room, WorkManager, DataStore

---

## Architecture

```
       iOS (SwiftUI)          Android (Compose)
              \                    /
               \                  /
          FoodshareCore (Swift 6.0)
          19 shared bridges via JNI
                    |
           Supabase Backend
     PostgreSQL + PostGIS + Auth + Realtime
```

---

## Shared Swift Bridges

| Bridge | What It Does |
|--------|-------------|
| Validation | Entity validation (listing, profile, auth) |
| Matching | Food matching algorithms |
| Gamification | Points, badges, streaks, leaderboards |
| Recommendations | ML-based personalized feed ranking |
| Geo Intelligence | Haversine distance, DBSCAN clustering, route optimization |
| Image Processing | Format detection, thumbnails, duplicate detection |
| Search Engine | NLP query parsing, spell correction, relevance scoring |
| Delta Sync | Version-based sync with conflict resolution + CRDTs |
| Network Resilience | Circuit breaker, retry strategies |
| Content Moderation | Profanity/toxicity/spam detection |
| Rate Limiting | Quota management, burst detection |
| Performance | Frame timing, memory profiling |
| Accessibility | WCAG contrast checking, audit |
| A/B Testing | Deterministic variants, Thompson Sampling |
| Error Recovery | Classification, circuit breaker, backoff |
| Security | AES-GCM encryption, attestation |
| Feature Flags | Rollout, versioning, experiments |
| Form State | Form validation engine |
| Batch Operations | Chunk sizing, backoff |

---

## Links

- **Repo:** https://github.com/Foodshareclub/foodshare-android
- **Forum Post:** https://forums.swift.org/t/83948
- **PR:** https://github.com/swiftlang/swift-org-website/pull/1281

---

## Submission Requirements

- [ ] 3-minute demo video (YouTube/Loom)
- [ ] GitHub repository (must be open source)
- [ ] Written summary (above, 100-200 words)
- [ ] Deadline: **Feb 16, 3:00 PM EST**

---

**Team:** Tarlan (organicnz) | **Built with:** Claude Code (Opus 4.6) | **Feb 2026**
