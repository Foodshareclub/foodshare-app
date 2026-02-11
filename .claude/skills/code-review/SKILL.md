---
name: code-review
description: Comprehensive code review for Foodshare Android. Use for PR reviews, architecture audits, security checks, and quality assurance. Catches issues before they reach production.
---

<objective>
Every line of code should be reviewed against Foodshare Android standards. Catch bugs, security issues, and design violations before they ship.
</objective>

<essential_principles>
## Review Checklist Categories

### 1. Architecture
- [ ] Clean Architecture layers respected (Domain -> Data -> Presentation)
- [ ] No cross-feature imports
- [ ] Dependencies injected via Hilt (not created internally)
- [ ] Domain layer has no infrastructure imports
- [ ] ViewModels expose StateFlow (not LiveData or mutableStateOf)

### 2. Concurrency
- [ ] Coroutines launched in viewModelScope
- [ ] No blocking calls on Main dispatcher
- [ ] Realtime channels cleaned up in onCleared
- [ ] Result type used for error handling (not try/catch in ViewModel)

### 3. Design System
- [ ] Uses LiquidGlassColors (not raw Color values)
- [ ] Uses LiquidGlassTypography (not raw TextStyle)
- [ ] Uses LiquidGlassSpacing (not raw Dp values)
- [ ] Uses Glass* components (not raw Material components)

### 4. Security
- [ ] No hardcoded secrets or API keys
- [ ] No service role key in client code
- [ ] Input sanitized via Swift ValidationBridge
- [ ] RLS policies in place for new tables
- [ ] Sensitive data not logged

### 5. Performance
- [ ] LazyColumn for dynamic lists (not Column)
- [ ] Stable keys provided to LazyColumn items
- [ ] Images loaded with Coil (not manual bitmap loading)
- [ ] No unnecessary recompositions
- [ ] Heavy work off Main thread

### 6. Swift Integration
- [ ] swift-java bridges used (not manual JNI)
- [ ] SwiftArena for memory management
- [ ] JNI bindings regenerated after Swift changes
- [ ] Both arm64-v8a and x86_64 .so files present

### 7. Testing
- [ ] ViewModel tests exist with fake repositories
- [ ] MainDispatcherRule used for coroutine tests
- [ ] Edge cases covered (empty, error, loading states)
- [ ] Swift tests pass

## Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| Blocker | Security/crash risk | Must fix before merge |
| Major | Bug or architecture violation | Should fix |
| Minor | Style/improvement | Nice to fix |
| Info | Suggestion | Optional |

## Common Issues to Flag

**Always Flag:**
- Force unwraps or `!!` operators
- Hardcoded secrets or API keys
- Missing RLS policies
- Memory leaks (uncleaned channels, coroutines)
- Blocking Main thread

**Usually Flag:**
- Raw colors/fonts/spacing
- Column for dynamic lists
- Missing error handling
- Missing tests for ViewModels
</essential_principles>

<success_criteria>
Review is complete when:
- [ ] All files examined
- [ ] Architecture compliance verified
- [ ] Security scan completed
- [ ] Design system compliance checked
- [ ] Performance implications considered
- [ ] Swift integration verified
- [ ] Test coverage assessed
- [ ] Clear feedback provided with severity levels
</success_criteria>
