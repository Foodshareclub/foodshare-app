package com.foodshare.core.crash

import android.content.Context
import com.flutterflow.foodshare.BuildConfig
import io.sentry.Sentry
import io.sentry.SentryLevel
import io.sentry.android.core.SentryAndroid
import io.sentry.protocol.User

/**
 * Sentry crash reporting initializer for Android
 */
object SentryInitializer {
    
    private var isInitialized = false
    
    /**
     * Initialize Sentry SDK
     * Call this in Application.onCreate()
     */
    fun init(context: Context) {
        if (isInitialized) return
        
        val dsn = BuildConfig.SENTRY_DSN
        if (dsn.isBlank()) {
            android.util.Log.w("Sentry", "SENTRY_DSN not configured - crash reporting disabled")
            return
        }
        
        SentryAndroid.init(context) { options ->
            options.dsn = dsn
            options.environment = if (BuildConfig.DEBUG) "development" else "production"
            options.release = "${BuildConfig.APPLICATION_ID}@${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}"
            
            // Performance monitoring
            options.tracesSampleRate = if (BuildConfig.DEBUG) 1.0 else 0.2
            options.profilesSampleRate = if (BuildConfig.DEBUG) 1.0 else 0.1
            
            // Session tracking
            options.isEnableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30_000
            
            // Breadcrumbs
            options.maxBreadcrumbs = 100
            options.isEnableActivityLifecycleBreadcrumbs = true
            options.isEnableAppComponentBreadcrumbs = true
            options.isEnableSystemEventBreadcrumbs = true
            options.isEnableAppLifecycleBreadcrumbs = true
            options.isEnableUserInteractionBreadcrumbs = true
            
            // Network
            options.isEnableNetworkEventBreadcrumbs = true
            
            // Debug
            options.isDebug = BuildConfig.DEBUG
            
            // Don't send PII by default
            options.isSendDefaultPii = false
        }
        
        isInitialized = true
    }
    
    /**
     * Set user context after authentication
     */
    fun setUser(userId: String, email: String? = null, username: String? = null) {
        if (!isInitialized) return
        
        Sentry.setUser(User().apply {
            id = userId
            this.email = email
            this.username = username
        })
    }
    
    /**
     * Clear user on logout
     */
    fun clearUser() {
        if (!isInitialized) return
        Sentry.setUser(null)
    }
    
    /**
     * Add breadcrumb for debugging
     */
    fun addBreadcrumb(
        category: String,
        message: String,
        level: SentryLevel = SentryLevel.INFO,
        data: Map<String, Any>? = null
    ) {
        if (!isInitialized) return
        
        Sentry.addBreadcrumb(io.sentry.Breadcrumb().apply {
            this.category = category
            this.message = message
            this.level = level
            data?.forEach { (key, value) -> setData(key, value) }
        })
    }
    
    /**
     * Capture exception
     */
    fun captureException(
        throwable: Throwable,
        context: Map<String, Any>? = null,
        tags: Map<String, String>? = null
    ) {
        if (!isInitialized) return
        
        Sentry.captureException(throwable) { scope ->
            context?.let { scope.setContexts("custom", it) }
            tags?.forEach { (key, value) -> scope.setTag(key, value) }
        }
    }
    
    /**
     * Capture message
     */
    fun captureMessage(message: String, level: SentryLevel = SentryLevel.INFO) {
        if (!isInitialized) return
        Sentry.captureMessage(message, level)
    }
}
