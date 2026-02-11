---
name: feature-development
description: End-to-end feature development workflow for Foodshare Android. Use when building new features from scratch. Orchestrates architecture, database, UI, and testing together.
---

<objective>
Deliver complete, production-ready Android features with proper architecture, Compose UI, Hilt DI, and comprehensive tests in one workflow.
</objective>

<essential_principles>
## Feature Development Phases

```
1. Requirements -> 2. Design -> 3. Database -> 4. Domain -> 5. Data -> 6. Presentation -> 7. Test -> 8. Review
```

## Phase 1: Requirements Clarification

Before writing ANY code, understand:
- What problem does this feature solve?
- What are the success criteria?
- What edge cases exist?
- Does it need database changes?
- Does it need Swift validation logic?

## Phase 2: Design Review

- Does this fit the Liquid Glass design system?
- What screens/flows?
- What states (loading, empty, error, success)?
- Mobile-first considerations?

## Phase 3: Database (if needed)

Create migration in `foodshare-backend/supabase/migrations/`:
```sql
BEGIN;
CREATE TABLE {table_name} (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX CONCURRENTLY idx_{table}_user ON {table_name}(user_id);
ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own {feature}" ON {table_name} FOR ALL USING (auth.uid() = user_id);
COMMIT;
```

## Phase 4: Domain Layer

```
domain/model/{Entity}.kt           # Pure Kotlin data class
domain/repository/{Entity}Repository.kt  # Interface
```

## Phase 5: Data Layer

```
data/repository/Supabase{Entity}Repository.kt  # Implementation with @Inject
```

## Phase 6: Presentation Layer

```
features/{feature}/
├── {Feature}ViewModel.kt      # @HiltViewModel, StateFlow<UiState>
└── {Feature}Screen.kt          # @Composable, state hoisting
```

## Phase 7: Testing

```
app/src/test/.../
├── {Feature}ViewModelTest.kt   # Unit test with fake repository
└── Fake{Entity}Repository.kt   # Test double
```

## Phase 8: Integration

- Add Hilt bindings in `di/AppModule.kt`
- Add route to Navigation graph
- Wire up Swift validation if needed
- Test complete flow
</essential_principles>

## Files Created (Typical Feature)

| Layer | Files | Lines |
|-------|-------|-------|
| Migration | 1 SQL file | ~20 |
| Domain | 1-2 Kotlin files | ~50 |
| Data | 1 repository impl | ~80 |
| Presentation | 1 ViewModel + 1-2 Screens | ~200 |
| DI | 1 binding in AppModule | ~5 |
| Tests | 1-2 test files | ~100 |
| **Total** | **6-8 files** | **~450** |

## Skills Invoked During Development

| Phase | Skill |
|-------|-------|
| Architecture | android-architecture |
| UI | kotlin-compose, liquid-glass-compose |
| Swift Bridge | swift-jni-integration |
| DI | hilt-di |
| Backend | supabase-kotlin |
| Testing | android-testing |
| Review | code-review |

<success_criteria>
Feature is complete when:
- [ ] All requirements are met
- [ ] Clean Architecture followed
- [ ] Liquid Glass design system enforced
- [ ] Hilt DI properly configured
- [ ] Tests written and passing
- [ ] Code reviewed
- [ ] Navigation wired up
</success_criteria>
