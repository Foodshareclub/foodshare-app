package com.foodshare.core.swift

import android.util.Log

/**
 * Initializes the Swift runtime for Android.
 *
 * This object handles loading the native Swift library (FoodshareCore) that
 * provides cross-platform domain models, validation, and business logic.
 *
 * Usage:
 * ```kotlin
 * // Call once at application startup
 * SwiftRuntime.initialize()
 *
 * // Then use Swift types via generated bindings
 * import com.foodshare.swift.*
 * val listing = FoodListing(...)
 * ```
 */
object SwiftRuntime {

    private const val TAG = "SwiftRuntime"
    private const val LIBRARY_NAME = "FoodshareCore"

    @Volatile
    private var isInitialized = false

    @Volatile
    private var initializationError: Throwable? = null

    /**
     * Initialize the Swift runtime by loading the native library.
     *
     * This method is idempotent - calling it multiple times has no effect
     * after the first successful initialization.
     *
     * @return true if initialization succeeded, false otherwise
     */
    @Synchronized
    fun initialize(): Boolean {
        if (isInitialized) {
            return true
        }

        return try {
            System.loadLibrary(LIBRARY_NAME)
            isInitialized = true
            initializationError = null
            Log.i(TAG, "Swift runtime initialized successfully")
            true
        } catch (e: UnsatisfiedLinkError) {
            initializationError = e
            Log.w(TAG, "Swift library not available: ${e.message}")
            Log.w(TAG, "Run './gradlew setupSwiftIntegration' to build Swift libraries")
            false
        } catch (e: SecurityException) {
            initializationError = e
            Log.e(TAG, "Security error loading Swift library: ${e.message}")
            false
        }
    }

    /**
     * Check if the Swift runtime is available.
     *
     * This attempts initialization if not already done.
     */
    val isAvailable: Boolean
        get() = isInitialized || initialize()

    /**
     * Get the initialization error, if any.
     */
    fun getError(): Throwable? = initializationError

    /**
     * Require the Swift runtime to be available.
     *
     * @throws IllegalStateException if Swift runtime is not available
     */
    fun requireAvailable() {
        if (!isAvailable) {
            throw IllegalStateException(
                "Swift runtime is not available. " +
                "Run './gradlew setupSwiftIntegration' to build Swift libraries. " +
                "Error: ${initializationError?.message}"
            )
        }
    }
}
