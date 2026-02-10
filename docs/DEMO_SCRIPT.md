# Demo Script: FoodShare Android

> 3-minute demo video for "Built with Opus 4.6" hackathon submission
> Format: Pre-recorded video (YouTube/Loom) -- max 3 minutes

---

## Elevator Pitch (15 seconds)

"FoodShare connects people with surplus food to those who need it. I built the entire Android app solo using Claude Code -- featuring a first-of-its-kind Swift-on-Android architecture sharing 95% of business logic with iOS."

---

## Demo Flow (3 minutes total)

### Act 1: The Problem & Solution (30s)

**Show:** Side-by-side iOS app + architecture diagram

- "FoodShare is live on iOS. 72% of the world uses Android -- we needed a companion app without duplicating 50,000 lines of logic."
- "The solution: a shared Swift core compiled for Android via JNI. 19 bridges, 37 modules, 17 screens -- built solo with Claude Code."

### Act 2: Live App Walkthrough (1m 15s)

**Walk through the Android app -- move fast, show breadth:**

1. **Feed screen** (15s) -- Show food listings loading
   - "Every listing validated through shared Swift -- identical rules on both platforms"

2. **Search + Map** (20s) -- Type a query, switch to map view
   - "NLP search with spell correction in Swift. PostGIS queries, DBSCAN clustering, native Compose rendering."

3. **Create listing** (20s) -- Start creating, show validation errors
   - "Real-time validation via Swift bridge -- same rules as iOS, zero duplication"

4. **Chat + Profile** (20s) -- Show messaging and gamification badges
   - "Real-time chat via Supabase Realtime. Gamification engine shared in Swift."

### Act 3: Under the Hood (45s)

**Show:** Code briefly -- keep it punchy

1. **Swift bridge** (20s) -- Flash `ValidationBridge.kt` + Swift `ListingValidator`
   - "swift-java -- official Swift-Java interop. This exact Swift code runs on both platforms."

2. **Build output** (10s) -- Show compiled `.so` files
   - "Cross-compiled to ARM64 and x86_64. 36 shared tests passing."

3. **Community contributions** (15s) -- Show PR/forum post
   - "We contributed back: PR to swift-org, forum case study, 4 upstream issues."

### Act 4: Claude Code Impact (30s)

- "Claude Code designed the architecture, generated all 19 JNI bridges, built 37 infrastructure modules, and drafted community contributions."
- "What would take a team months -- one developer, one hackathon, one tool."
- "This is what 'Break the Barriers' means: Claude Code makes bleeding-edge cross-platform architecture accessible to everyone."

---

## Judging Criteria Checklist

| Criteria | Weight | What to Emphasize |
|----------|--------|-------------------|
| **Demo** | 30% | Working app, live data, real features -- show it running |
| **Impact** | 25% | Food waste problem, 72% Android market, ecosystem contributions |
| **Opus 4.6 Use** | 25% | Architecture design, JNI bridge generation, 37 modules, community PRs |
| **Depth & Execution** | 20% | 19 phases, swift-java migration, CRDTs, ML, DBSCAN -- not a quick hack |

### Key Talking Points

**Technical:** Swift-on-Android at scale, swift-java migration, delta sync with CRDTs, 36 shared tests

**Product:** 95% code sharing, single source of truth, fix-once-deploy-everywhere, community impact

**Claude Code:** Designed architecture, generated all bridges, built 37 modules with consistent patterns, drafted community contributions

---

## Potential Questions & Answers

**Q: Why Swift on Android instead of Kotlin Multiplatform?**
A: Our iOS app is already written in Swift. Sharing the existing Swift code is more efficient than rewriting everything in Kotlin. Plus, we're contributing to the nascent Swift-on-Android ecosystem.

**Q: What's the performance overhead of JNI?**
A: Minimal. We batch operations to reduce JNI crossings, and swift-java handles memory efficiently via SwiftArena. The shared logic (validation, sync, search) is not in the hot path -- UI rendering stays fully native Compose.

**Q: Is Swift on Android production-ready?**
A: The SDK is in nightly preview, but it works. We've documented 8 workarounds and contributed fixes upstream. Frameo.com uses swift-java in production today.

**Q: How much did Claude Code actually write vs. you?**
A: Claude Code was the primary author of ~90% of the code. My role was architecture direction, code review, and testing. Claude Code handled the tedious parts -- JNI bindings, module boilerplate, consistent patterns across 37 modules.

**Q: What was the hardest part?**
A: The JNI bridge layer. Managing memory safely across Swift and Kotlin is error-prone. Claude Code's ability to generate consistent, safe bridge code across 19 modules was the key unlock.

---

## Screens to Show

| Screen | Key Feature | Bridge Used |
|--------|-------------|-------------|
| Feed | Listing cards with distance | GeoIntelligenceBridge |
| Search | NLP query parsing | SearchEngineBridge |
| Map | Clustered markers | GeoIntelligenceBridge |
| Create Listing | Real-time validation | ValidationBridge |
| Chat | Real-time messaging | -- (native Supabase) |
| Profile | Gamification badges | GamificationBridge |
| Settings | Accessibility audit | AccessibilityBridge |

---

## Demo Backup Plan

Since this is a pre-recorded video, record multiple takes and pick the best. If app has issues during recording:

1. **Screen recording + voiceover** -- Record app separately, add narration
2. **Fallback to screenshots** -- Prepare 5-7 app screenshots with transitions
3. **Code walkthrough** -- Bridge architecture in IDE is compelling on its own
4. **Build + tests** -- `./gradlew buildSwiftRelease && ./gradlew testSwift` (36 tests passing)

---

## Recording Tips

- Use screen recording at 1080p or higher
- Keep transitions fast -- judges see many demos
- Show the app doing real things, not just static screens
- End with the closing statement strong -- it's what they'll remember
- Upload to YouTube (unlisted) or Loom before deadline

---

*Prepared for Built with Opus 4.6 | February 2026 | Deadline: Feb 16, 3:00 PM EST*
