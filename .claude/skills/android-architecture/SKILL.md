---
name: android-architecture
description: Enforce Clean Architecture with MVVM for Foodshare Android. Use when creating features, reviewing code, or diagnosing layer violations. Ensures Domain -> Data -> Presentation separation with Hilt dependency injection.
---

<objective>
Ensure all Foodshare Android code follows Clean Architecture principles with strict layer separation, testability, and maintainability.
</objective>

<essential_principles>
## Core Architecture Rules (Non-Negotiable)

**Layer Direction:** Presentation -> Domain <- Data

1. **Domain Layer** (Pure Kotlin)
   - Models, Repository interfaces
   - NO imports of Android framework, Supabase, or infrastructure
   - Business logic lives in domain models and use cases

2. **Data Layer** (Implementations)
   - Repository implementations (`Supabase*Repository`)
   - DTOs with `@Serializable`
   - Can import infrastructure, implements domain interfaces

3. **Presentation Layer** (UI)
   - Compose screens and ViewModels
   - NO business logic, NO direct service calls
   - ViewModels expose `StateFlow<UiState>` to Compose

**Ultra-Thin Client:**

| Android Does | Supabase Does |
|---|---|
| Display data (Compose) | Store/validate data (PostgreSQL) |
| Collect user input | Authorization (RLS policies) |
| Call Supabase client | Business logic (Edge Functions) |
| Offline cache (Room) | Complex queries (PostGIS) |
| Input sanitization (Swift) | Server-side validation |

**Red Flags (Instant Violations):**
- ViewModel imports Supabase directly -> WRONG (use repository interface)
- Domain model has `@Serializable` -> WRONG (that's a DTO)
- Composable contains `suspend` calls -> WRONG (call ViewModel)
- Feature imports another feature -> WRONG (use Core)
</essential_principles>

## File Organization

```
features/{FeatureName}/
├── domain/
│   └── model/          # Pure Kotlin data classes
├── data/
│   └── repository/     # Supabase implementations
└── presentation/
    ├── {Feature}ViewModel.kt   # @HiltViewModel, StateFlow<UiState>
    └── {Feature}Screen.kt      # @Composable
```

Top-level shared layers:
```
domain/
├── model/              # Shared domain models (FoodListing, UserProfile, etc.)
└── repository/         # Shared repository interfaces

data/repository/        # Supabase*Repository implementations
```

## ViewModel Template

```kotlin
@HiltViewModel
class FeedViewModel @Inject constructor(
    private val feedRepository: FeedRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(FeedUiState())
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    fun loadFeed() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            feedRepository.getFeed()
                .onSuccess { items ->
                    _uiState.update { it.copy(items = items, isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message, isLoading = false) }
                }
        }
    }
}

data class FeedUiState(
    val items: List<FoodListing> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)
```

## Repository Interface Template

```kotlin
interface FeedRepository {
    suspend fun getFeed(): Result<List<FoodListing>>
    suspend fun getListingById(id: String): Result<FoodListing>
    suspend fun createListing(listing: FoodListing): Result<FoodListing>
}
```

<success_criteria>
Architecture is correct when:
- [ ] Domain layer has zero infrastructure imports
- [ ] ViewModels receive dependencies via @Inject constructor
- [ ] Composables only observe StateFlow, no async logic
- [ ] Features don't import other features
- [ ] All repository interfaces are in domain, implementations in data
- [ ] DTOs are separate from domain models
- [ ] Hilt modules provide all bindings
</success_criteria>
