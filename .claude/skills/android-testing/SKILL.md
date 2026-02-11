---
name: android-testing
description: Testing patterns for Foodshare Android. Use when writing unit tests, instrumented tests, or Swift tests. Covers JUnit, Hilt test injection, coroutine testing, and Swift test validation.
---

<objective>
Write comprehensive tests for Foodshare Android covering ViewModels, repositories, and Swift integration with proper Hilt injection and coroutine handling.
</objective>

<essential_principles>
## Test Structure

```
app/src/test/               # Unit tests (JVM)
app/src/androidTest/        # Instrumented tests (device/emulator)
foodshare-core/Tests/       # Swift tests (host machine)
```

## Commands

```bash
./gradlew test                    # Unit tests
./gradlew connectedAndroidTest    # Instrumented tests
./gradlew testSwift               # Swift tests (36 tests)
```

## ViewModel Unit Tests

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class FeedViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var viewModel: FeedViewModel
    private val fakeRepository = FakeFeedRepository()

    @Before
    fun setup() {
        viewModel = FeedViewModel(fakeRepository)
    }

    @Test
    fun `loadFeed updates state with listings`() = runTest {
        fakeRepository.setListings(listOf(FoodListing.fixture()))

        viewModel.loadFeed()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals(1, state.items.size)
        assertNull(state.error)
    }

    @Test
    fun `loadFeed handles error`() = runTest {
        fakeRepository.setShouldFail(true)

        viewModel.loadFeed()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNotNull(state.error)
    }
}
```

## MainDispatcherRule (Required for ViewModel tests)

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(dispatcher)
    }
    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}
```

## Fake Repository Pattern

```kotlin
class FakeFeedRepository : FeedRepository {
    private var listings = emptyList<FoodListing>()
    private var shouldFail = false

    fun setListings(items: List<FoodListing>) { listings = items }
    fun setShouldFail(fail: Boolean) { shouldFail = fail }

    override suspend fun getFeed(): Result<List<FoodListing>> {
        return if (shouldFail) Result.failure(Exception("Test error"))
        else Result.success(listings)
    }
}
```

## Hilt Instrumented Tests

```kotlin
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class FeedScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun setup() { hiltRule.inject() }

    @Test
    fun feedScreen_displaysListings() {
        composeRule.onNodeWithText("Fresh Bread").assertIsDisplayed()
    }
}
```

## Test Fixtures

```kotlin
fun FoodListing.Companion.fixture(
    id: String = UUID.randomUUID().toString(),
    title: String = "Test Listing",
    description: String = "Test description",
) = FoodListing(id = id, title = title, description = description)
```
</essential_principles>

<success_criteria>
Testing is correct when:
- [ ] ViewModels tested with fake repositories
- [ ] MainDispatcherRule used for coroutine tests
- [ ] Hilt injection working in instrumented tests
- [ ] Swift tests passing (`./gradlew testSwift`)
- [ ] Error states and edge cases covered
- [ ] Test fixtures used for consistent test data
</success_criteria>
