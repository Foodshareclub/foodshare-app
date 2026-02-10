# Add project specific ProGuard rules here.

# Supabase-kt
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep @Serializable classes
-keep,includedescriptorclasses class com.foodshare.**$$serializer { *; }
-keepclassmembers class com.foodshare.** {
    *** Companion;
}
-keepclasseswithmembers class com.foodshare.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep domain models
-keep class com.foodshare.domain.model.** { *; }

# Keep DTOs for serialization
-keep class com.foodshare.data.dto.** { *; }

# Keep core network classes
-keep class com.foodshare.core.network.** { *; }
-keep class com.foodshare.core.error.** { *; }
-keep class com.foodshare.core.sync.** { *; }
-keep class com.foodshare.core.realtime.** { *; }
-keep class com.foodshare.core.push.** { *; }

# Compose
-dontwarn androidx.compose.**

# Coil
-dontwarn coil.**

# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.room.paging.**

# WorkManager
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}

# Hilt Worker
-keep class * extends androidx.hilt.work.HiltWorker

# Ktor - suppress warnings for JVM management classes not available on Android
-dontwarn java.lang.management.ManagementFactory
-dontwarn java.lang.management.RuntimeMXBean

# Google Play Services Location - suppress companion object warning
-dontwarn com.google.android.gms.internal.location.**
