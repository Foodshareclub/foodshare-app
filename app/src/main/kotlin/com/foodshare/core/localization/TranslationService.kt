package com.foodshare.core.localization

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import java.io.File
import java.io.IOException
import java.util.*
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Enterprise-grade translation service for cross-platform localization.
 * Features: caching, delta sync, offline support, ETag-based conditional requests.
 */
@Singleton
class TranslationService @Inject constructor(
    private val context: Context
) {
    companion object {
        private const val TAG = "TranslationService"
        private const val BASE_URL = "https://api.foodshare.club/functions/v1/get-translations"
        private const val DEFAULT_LOCALE = "en"
        private const val PREFS_NAME = "translation_prefs"
        private const val KEY_LOCALE = "app_locale"
        private const val CACHE_EXPIRATION_HOURS = 2L

        val SUPPORTED_LOCALES = listOf(
            "en", "cs", "de", "es", "fr", "pt", "ru", "uk", "zh",
            "hi", "ar", "it", "pl", "nl", "ja", "ko", "tr"
        )

        @Volatile
        private var instance: TranslationService? = null

        fun getInstance(context: Context): TranslationService {
            return instance ?: synchronized(this) {
                instance ?: TranslationService(context.applicationContext).also { instance = it }
            }
        }
    }

    // State
    private val _currentLocale = MutableStateFlow(detectSystemLocale())
    val currentLocale: StateFlow<String> = _currentLocale.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _lastSyncDate = MutableStateFlow<Date?>(null)
    val lastSyncDate: StateFlow<Date?> = _lastSyncDate.asStateFlow()

    private val _error = MutableStateFlow<TranslationError?>(null)
    val error: StateFlow<TranslationError?> = _error.asStateFlow()

    // Internal
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val cache = TranslationCache(context)
    private val httpClient = createHttpClient()
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var translations: Map<String, Any> = emptyMap()
    private val etags = mutableMapOf<String, String>()

    init {
        // Load cached translations on init
        scope.launch {
            loadCachedTranslations()
        }
    }

    // MARK: - Public API

    /**
     * Get a translated string for the given key
     */
    fun t(key: String, locale: String? = null): String {
        val targetLocale = locale ?: _currentLocale.value
        return getValue(key, targetLocale) ?: key
    }

    /**
     * Get a translated string with named arguments
     */
    fun t(key: String, args: Map<String, String>, locale: String? = null): String {
        var result = t(key, locale)
        args.forEach { (placeholder, value) ->
            result = result.replace("{$placeholder}", value)
        }
        return result
    }

    /**
     * Get a translated string with positional arguments
     */
    fun t(key: String, vararg args: String, locale: String? = null): String {
        var result = t(key, locale)
        args.forEachIndexed { index, value ->
            result = result.replace("{$index}", value)
        }
        return result
    }

    /**
     * Change the current locale
     */
    suspend fun setLocale(locale: String) {
        if (!SUPPORTED_LOCALES.contains(locale)) {
            throw TranslationError.UnsupportedLocale(locale)
        }

        _currentLocale.value = locale
        prefs.edit().putString(KEY_LOCALE, locale).apply()

        // Sync translations for new locale
        sync(locale)
    }

    /**
     * Sync translations from server
     */
    suspend fun sync(locale: String? = null, force: Boolean = false) {
        val targetLocale = locale ?: _currentLocale.value

        // Check if sync is needed
        if (!force) {
            cache.getLastSyncDate(targetLocale)?.let { lastSync ->
                val hoursSinceSync = (Date().time - lastSync.time) / (1000 * 60 * 60)
                if (hoursSinceSync < CACHE_EXPIRATION_HOURS) {
                    Log.d(TAG, "Skipping sync for $targetLocale, last sync was $hoursSinceSync hours ago")
                    return
                }
            }
        }

        _isLoading.value = true
        _error.value = null

        try {
            val cachedVersion = cache.getVersion(targetLocale)
            val response = fetchTranslations(targetLocale, cachedVersion)

            // Handle 304 Not Modified
            if (response.notModified) {
                Log.d(TAG, "Translations not modified for $targetLocale")
                cache.updateLastSyncDate(targetLocale)
                _lastSyncDate.value = Date()
                return
            }

            // Update cache and in-memory translations
            response.messages?.let { messages ->
                cache.save(
                    messages = messages,
                    version = response.version ?: "unknown",
                    etag = response.etag,
                    locale = targetLocale
                )

                if (targetLocale == _currentLocale.value) {
                    translations = messages
                }

                _lastSyncDate.value = Date()
                Log.i(TAG, "Synced translations for $targetLocale, version: ${response.version}")
            }
        } catch (e: Exception) {
            _error.value = TranslationError.SyncFailed(e.message ?: "Unknown error")
            Log.e(TAG, "Failed to sync translations", e)
            throw e
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * Prefetch translations for multiple locales
     */
    suspend fun prefetch(locales: List<String>) {
        coroutineScope {
            locales.filter { SUPPORTED_LOCALES.contains(it) }.map { locale ->
                async {
                    try {
                        sync(locale)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to prefetch $locale", e)
                    }
                }
            }.awaitAll()
        }
    }

    /**
     * Clear all cached translations
     */
    fun clearCache() {
        cache.clearAll()
        translations = emptyMap()
        _lastSyncDate.value = null
    }

    // MARK: - Private Methods

    private suspend fun loadCachedTranslations() {
        cache.load(_currentLocale.value)?.let { cached ->
            translations = cached.messages
            _lastSyncDate.value = cached.lastSync
            Log.d(TAG, "Loaded cached translations for ${_currentLocale.value}")
        }

        // Background sync
        withContext(Dispatchers.IO) {
            try {
                sync()
            } catch (e: Exception) {
                Log.w(TAG, "Background sync failed", e)
            }
        }
    }

    private fun getValue(key: String, locale: String): String? {
        // Try current locale first
        getNestedValue(key, translations)?.let { return it }

        // Try cached locale if different
        if (locale != _currentLocale.value) {
            cache.load(locale)?.messages?.let { cached ->
                getNestedValue(key, cached)?.let { return it }
            }
        }

        // Fallback to English
        if (locale != DEFAULT_LOCALE) {
            cache.load(DEFAULT_LOCALE)?.messages?.let { cached ->
                getNestedValue(key, cached)?.let { return it }
            }
        }

        return null
    }

    @Suppress("UNCHECKED_CAST")
    private fun getNestedValue(key: String, dict: Map<String, Any>): String? {
        val parts = key.split(".")
        var current: Any = dict

        for (part in parts) {
            current = when (current) {
                is Map<*, *> -> (current as Map<String, Any>)[part] ?: return null
                else -> return null
            }
        }

        return current as? String
    }

    private fun detectSystemLocale(): String {
        // Check saved preference first
        prefs.getString(KEY_LOCALE, null)?.let { saved ->
            if (SUPPORTED_LOCALES.contains(saved)) return saved
        }

        // Use system locale
        val systemLocale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0].language
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale.language
        }

        return if (SUPPORTED_LOCALES.contains(systemLocale)) systemLocale else DEFAULT_LOCALE
    }

    private fun createHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val request = chain.request().newBuilder()
                    .addHeader("Accept", "application/json")
                    .addHeader("Accept-Encoding", "gzip, deflate")
                    .addHeader("X-Platform", "android")
                    .addHeader("X-App-Version", getAppVersion())
                    .addHeader("X-OS-Version", Build.VERSION.RELEASE)
                    .build()
                chain.proceed(request)
            }
            .build()
    }

    private fun getAppVersion(): String {
        return try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    private suspend fun fetchTranslations(locale: String, version: String?): TranslationResponse {
        return withContext(Dispatchers.IO) {
            val url = HttpUrl.Builder()
                .scheme("https")
                .host("api.foodshare.club")
                .addPathSegments("functions/v1/get-translations")
                .addQueryParameter("locale", locale)
                .addQueryParameter("platform", "android")
                .build()

            val requestBuilder = Request.Builder()
                .url(url)
                .get()

            // Add ETag for conditional request
            etags[locale]?.let { etag ->
                requestBuilder.addHeader("If-None-Match", "\"$etag\"")
            }

            val request = requestBuilder.build()

            httpClient.newCall(request).execute().use { response ->
                // Handle 304 Not Modified
                if (response.code == 304) {
                    return@withContext TranslationResponse(
                        messages = null,
                        version = null,
                        etag = null,
                        notModified = true
                    )
                }

                if (!response.isSuccessful) {
                    throw TranslationError.NetworkError("HTTP ${response.code}")
                }

                val body = response.body?.string()
                    ?: throw TranslationError.ParseError("Empty response body")

                val jsonResponse = json.parseToJsonElement(body).jsonObject

                val success = jsonResponse["success"]?.jsonPrimitive?.booleanOrNull ?: false
                if (!success) {
                    throw TranslationError.ParseError("API returned success=false")
                }

                val data = jsonResponse["data"]?.jsonObject
                    ?: throw TranslationError.ParseError("Missing data field")

                val messages = data["messages"]?.jsonObject?.toMap()
                    ?: throw TranslationError.ParseError("Missing messages field")

                val responseVersion = data["version"]?.jsonPrimitive?.contentOrNull
                val responseEtag = response.header("ETag")?.replace("\"", "")

                // Store ETag for future requests
                responseEtag?.let { etags[locale] = it }

                TranslationResponse(
                    messages = messages,
                    version = responseVersion,
                    etag = responseEtag,
                    notModified = false
                )
            }
        }
    }

    private fun JsonObject.toMap(): Map<String, Any> {
        return entries.associate { (key, value) ->
            key to value.toAny()
        }
    }

    private fun JsonElement.toAny(): Any {
        return when (this) {
            is JsonPrimitive -> {
                when {
                    isString -> content
                    else -> content
                }
            }
            is JsonObject -> toMap()
            is JsonArray -> map { it.toAny() }
            else -> toString()
        }
    }

    // MARK: - Data Classes

    private data class TranslationResponse(
        val messages: Map<String, Any>?,
        val version: String?,
        val etag: String?,
        val notModified: Boolean
    )
}

// MARK: - Translation Error

sealed class TranslationError : Exception() {
    data class UnsupportedLocale(val locale: String) : TranslationError() {
        override val message = "Unsupported locale: $locale"
    }

    data class SyncFailed(override val message: String) : TranslationError()
    data class NetworkError(override val message: String) : TranslationError()
    data class ParseError(override val message: String) : TranslationError()
}

// MARK: - Translation Cache

private class TranslationCache(context: Context) {
    private val cacheDir = File(context.cacheDir, "translations").apply { mkdirs() }
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = false }

    @Serializable
    data class CachedTranslation(
        val messages: Map<String, JsonElement>,
        val version: String,
        val etag: String?,
        val lastSyncTimestamp: Long
    )

    data class LoadedTranslation(
        val messages: Map<String, Any>,
        val version: String,
        val lastSync: Date
    )

    fun save(messages: Map<String, Any>, version: String, etag: String?, locale: String) {
        try {
            val cached = CachedTranslation(
                messages = messages.mapValues { Json.encodeToJsonElement(it.value.toString()) },
                version = version,
                etag = etag,
                lastSyncTimestamp = System.currentTimeMillis()
            )

            val file = File(cacheDir, "$locale.json")
            file.writeText(json.encodeToString(CachedTranslation.serializer(), cached))
        } catch (e: Exception) {
            Log.e("TranslationCache", "Failed to save cache", e)
        }
    }

    fun load(locale: String): LoadedTranslation? {
        return try {
            val file = File(cacheDir, "$locale.json")
            if (!file.exists()) return null

            val cached = json.decodeFromString(CachedTranslation.serializer(), file.readText())
            LoadedTranslation(
                messages = cached.messages.mapValues { it.value.toString().trim('"') },
                version = cached.version,
                lastSync = Date(cached.lastSyncTimestamp)
            )
        } catch (e: Exception) {
            Log.e("TranslationCache", "Failed to load cache", e)
            null
        }
    }

    fun getVersion(locale: String): String? = load(locale)?.version

    fun getLastSyncDate(locale: String): Date? = load(locale)?.lastSync

    fun updateLastSyncDate(locale: String) {
        load(locale)?.let { existing ->
            save(existing.messages, existing.version, null, locale)
        }
    }

    fun clearAll() {
        cacheDir.listFiles()?.forEach { it.delete() }
    }
}

// MARK: - Compose Extensions

/**
 * Composable function to get translated string
 */
@Composable
fun stringResource(key: String): String {
    val service = TranslationService.getInstance(LocalContext.current)
    return service.t(key)
}

/**
 * Composable function to get translated string with args
 */
@Composable
fun stringResource(key: String, vararg args: String): String {
    val service = TranslationService.getInstance(LocalContext.current)
    return service.t(key, *args)
}
