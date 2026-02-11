---
name: hilt-di
description: Hilt dependency injection patterns for Foodshare Android. Use when creating modules, scoping dependencies, injecting into ViewModels, or setting up test configurations. Covers AppModule, feature-specific modules, and testing with Hilt.
---

<objective>
Manage all dependencies through Hilt with correct scoping, ensuring ViewModels and repositories are properly injected and testable.
</objective>

<essential_principles>
## Core Rules

1. **Application class** annotated with `@HiltAndroidApp` (`FoodShareApplication.kt`)
2. **Activities** annotated with `@AndroidEntryPoint` (`MainActivity.kt`)
3. **ViewModels** annotated with `@HiltViewModel` with `@Inject constructor`
4. **Modules** provide bindings via `@Module` + `@InstallIn`
5. **Repository interfaces** bound in modules, implementations injected

## Key File: `di/AppModule.kt`

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class AppModule {

    @Binds
    @Singleton
    abstract fun bindFeedRepository(
        impl: SupabaseFeedRepository,
    ): FeedRepository

    @Binds
    @Singleton
    abstract fun bindAuthRepository(
        impl: SupabaseAuthRepository,
    ): AuthRepository

    companion object {
        @Provides
        @Singleton
        fun provideSupabaseClient(): SupabaseClient {
            return createSupabaseClient(
                supabaseUrl = BuildConfig.SUPABASE_URL,
                supabaseKey = BuildConfig.SUPABASE_ANON_KEY,
            ) {
                install(Auth)
                install(Postgrest)
                install(Realtime)
                install(Storage)
            }
        }
    }
}
```

## Scoping Rules

| Scope | Annotation | Lifecycle |
|-------|-----------|-----------|
| Application-wide | `@Singleton` + `SingletonComponent` | App lifetime |
| Activity-scoped | `ActivityComponent` | Activity lifetime |
| ViewModel-scoped | `ViewModelComponent` | ViewModel lifetime |
| Fragment-scoped | `FragmentComponent` | Fragment lifetime |

**Default to `@Singleton`** for repositories, clients, and bridges.

## ViewModel Injection

```kotlin
@HiltViewModel
class ListingViewModel @Inject constructor(
    private val listingRepository: ListingRepository,
    private val validationBridge: ValidationBridge,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val listingId: String = savedStateHandle["id"] ?: ""
    // ...
}
```

## Testing with Hilt

```kotlin
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class FeedViewModelTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject
    lateinit var feedRepository: FeedRepository

    @Module
    @InstallIn(SingletonComponent::class)
    abstract class TestModule {
        @Binds
        abstract fun bindFeedRepository(
            impl: FakeFeedRepository,
        ): FeedRepository
    }

    @Before
    fun setup() {
        hiltRule.inject()
    }
}
```
</essential_principles>

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Creating dependencies manually in ViewModel | `@Inject constructor` |
| Using `object` singletons | Hilt `@Singleton` |
| `@Provides` for interfaces with single impl | `@Binds` (more efficient) |
| Missing `@AndroidEntryPoint` on Activity | Add annotation |

<success_criteria>
DI is correct when:
- [ ] All ViewModels use `@HiltViewModel` + `@Inject constructor`
- [ ] All repository interfaces bound via `@Binds` in modules
- [ ] Supabase client provided as `@Singleton`
- [ ] Test modules can replace production bindings
- [ ] No manual dependency construction in ViewModels
</success_criteria>
