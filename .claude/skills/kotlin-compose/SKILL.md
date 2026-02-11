---
name: kotlin-compose
description: Jetpack Compose + Material 3 patterns for Foodshare Android. Use when building UI, creating screens, handling state, or working with navigation. Ensures correct Compose idioms and Liquid Glass theming.
---

<objective>
Write idiomatic Jetpack Compose code using Material 3, proper state management with StateFlow, and Compose Navigation for all Foodshare Android screens.
</objective>

<essential_principles>
## Core Compose Rules

1. **State hoisting** - Composables receive state via parameters, emit events via lambdas
2. **StateFlow** - ViewModels expose `StateFlow<UiState>`, screens collect with `collectAsStateWithLifecycle()`
3. **Material 3** - All components use Material 3 via Liquid Glass theme (never raw Material defaults)
4. **Compose Navigation** - Type-safe routes with `NavHost` and `composable()` destinations
5. **Lifecycle-aware** - Use `collectAsStateWithLifecycle()` (not `collectAsState()`)

## Screen Template

```kotlin
@Composable
fun FeedScreen(
    viewModel: FeedViewModel = hiltViewModel(),
    onListingClick: (String) -> Unit,
    onCreateClick: () -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadFeed()
    }

    FeedContent(
        uiState = uiState,
        onListingClick = onListingClick,
        onCreateClick = onCreateClick,
        onRefresh = viewModel::loadFeed,
    )
}

@Composable
private fun FeedContent(
    uiState: FeedUiState,
    onListingClick: (String) -> Unit,
    onCreateClick: () -> Unit,
    onRefresh: () -> Unit,
) {
    // Pure UI - no ViewModel reference
    when {
        uiState.isLoading -> LoadingIndicator()
        uiState.error != null -> ErrorState(uiState.error, onRetry = onRefresh)
        uiState.items.isEmpty() -> EmptyState()
        else -> FeedList(uiState.items, onListingClick)
    }
}
```

## Navigation Pattern

```kotlin
// Routes as sealed class
sealed class Route(val route: String) {
    data object Feed : Route("feed")
    data object Search : Route("search")
    data class ListingDetail(val id: String) : Route("listing/{id}")
}

// NavHost setup
NavHost(navController = navController, startDestination = Route.Feed.route) {
    composable(Route.Feed.route) {
        FeedScreen(
            onListingClick = { id -> navController.navigate("listing/$id") },
            onCreateClick = { navController.navigate("create") },
        )
    }
}
```

## State Management

```kotlin
// Sealed interface for complex states
sealed interface FeedUiState {
    data object Loading : FeedUiState
    data class Success(val items: List<FoodListing>) : FeedUiState
    data class Error(val message: String) : FeedUiState
}

// Or data class for simpler states
data class ProfileUiState(
    val profile: UserProfile? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
)
```

## Lists (Performance)

```kotlin
// Always use LazyColumn for dynamic lists
LazyColumn(
    modifier = Modifier.fillMaxSize(),
    contentPadding = PaddingValues(LiquidGlassSpacing.md),
    verticalArrangement = Arrangement.spacedBy(LiquidGlassSpacing.sm),
) {
    items(
        items = listings,
        key = { it.id },  // Always provide key for stable recomposition
    ) { listing ->
        FoodItemCard(listing = listing, onClick = { onListingClick(listing.id) })
    }
}
```
</essential_principles>

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| `collectAsState()` | `collectAsStateWithLifecycle()` |
| `mutableStateOf()` in ViewModel | `MutableStateFlow()` |
| ViewModel in content composable | Hoist to screen-level only |
| `remember { mutableStateOf() }` for server data | StateFlow from ViewModel |
| Hardcoded strings | `stringResource(R.string.x)` |
| `Column` for long lists | `LazyColumn` with `key` |

<success_criteria>
Compose code is correct when:
- [ ] State hoisted properly (screen vs content split)
- [ ] StateFlow collected with lifecycle awareness
- [ ] Navigation uses typed routes
- [ ] Lists use LazyColumn with stable keys
- [ ] All text uses string resources
- [ ] Liquid Glass theme tokens used exclusively
- [ ] Preview annotations present for reusable composables
</success_criteria>
