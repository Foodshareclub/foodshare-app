package com.foodshare

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.foodshare.core.crash.SentryInitializer
import com.foodshare.core.push.NotificationChannels
import com.foodshare.core.swift.SwiftRuntime
import com.foodshare.core.sync.SyncWorker
import com.foodshare.ui.theme.ThemeManager
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class FoodShareApplication : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    override fun onCreate() {
        super.onCreate()

        // Initialize Sentry crash reporting first (before any potential crashes)
        SentryInitializer.init(this)

        // Initialize Swift runtime for cross-platform domain layer
        // This is non-blocking and gracefully handles missing libraries
        SwiftRuntime.initialize()

        // Initialize theme manager with persistence
        ThemeManager.initialize(this)

        // Create notification channels for Android O+
        NotificationChannels.createAll(this)

        // Schedule background sync
        SyncWorker.schedulePeriodicSync(this, intervalMinutes = 15)

        // Hilt handles dependency injection initialization
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .build()
}
