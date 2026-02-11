---
name: supabase-kotlin
description: supabase-kt integration patterns for Foodshare Android. Use when working with authentication, realtime subscriptions, RLS, storage, or database queries. Covers the Kotlin Supabase client SDK.
---

<objective>
Correctly use supabase-kt for all backend operations including auth, database queries, realtime subscriptions, and storage, following Foodshare's ultra-thin client pattern.
</objective>

<essential_principles>
## Core Rules

1. **Singleton client** - One `SupabaseClient` instance provided by Hilt (`AppModule.kt`)
2. **Ultra-thin client** - Android only displays data and collects input; Supabase handles validation, auth, and business logic
3. **RLS-first** - All queries go through RLS. Service role is never used client-side
4. **Repository pattern** - All Supabase calls go through repository implementations in `data/repository/`

## Client Setup (via Hilt)

```kotlin
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
```

## Authentication

```kotlin
// Sign in
supabase.auth.signInWith(Email) {
    email = userEmail
    password = userPassword
}

// Get current session
val session = supabase.auth.currentSessionOrNull()

// Sign out
supabase.auth.signOut()

// Listen to auth state
supabase.auth.sessionStatus.collect { status ->
    when (status) {
        is SessionStatus.Authenticated -> { /* logged in */ }
        is SessionStatus.NotAuthenticated -> { /* logged out */ }
        else -> { /* loading */ }
    }
}
```

## Database Queries (Postgrest)

```kotlin
// Fetch with filters
val listings = supabase.from("food_listings")
    .select {
        filter { eq("status", "available") }
        order("created_at", Order.DESCENDING)
        limit(20)
    }
    .decodeList<FoodListingDTO>()

// Insert
val newListing = supabase.from("food_listings")
    .insert(listingDTO)
    .decodeSingle<FoodListingDTO>()

// Update
supabase.from("food_listings")
    .update({ set("status", "claimed") }) {
        filter { eq("id", listingId) }
    }

// RPC (server functions)
val result = supabase.postgrest.rpc("nearby_listings", mapOf(
    "lat" to latitude,
    "lng" to longitude,
    "radius_km" to radius,
)).decodeList<FoodListingDTO>()
```

## Realtime Subscriptions

```kotlin
val channel = supabase.channel("chat-room-$roomId")

val messagesFlow = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
    table = "messages"
    filter = "room_id=eq.$roomId"
}.map { it.decodeRecord<MessageDTO>() }

channel.subscribe()

// Cleanup in ViewModel onCleared
override fun onCleared() {
    viewModelScope.launch { supabase.removeChannel(channel) }
}
```

## Storage

```kotlin
// Upload image
val bucket = supabase.storage.from("food-images")
val path = "listings/$listingId/${UUID.randomUUID()}.jpg"
bucket.upload(path, imageBytes)

// Get public URL
val url = bucket.publicUrl(path)
```

## Environment

Self-hosted Supabase at `https://api.foodshare.club`. Credentials in `local.properties` (gitignored), accessed via `BuildConfig`.
</essential_principles>

<success_criteria>
Supabase integration is correct when:
- [ ] Single SupabaseClient instance via Hilt
- [ ] All queries in repository implementations (not ViewModels)
- [ ] DTOs use `@Serializable` (not domain models)
- [ ] Realtime channels cleaned up in onCleared
- [ ] Auth state observed reactively
- [ ] No service role key in client code
</success_criteria>
