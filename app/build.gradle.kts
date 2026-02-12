import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
    id("com.google.dagger.hilt.android")
    id("io.sentry.android.gradle") version "5.5.0"
}

// Load local.properties
val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        load(localPropertiesFile.inputStream())
    }
}

// Check if we should skip native build (for CI)
val skipNativeBuild = project.hasProperty("skipNativeBuild") || 
    System.getenv("CI") == "true" ||
    localProperties.getProperty("skipNativeBuild", "false") == "true"

android {
    namespace = "com.flutterflow.foodshare"
    compileSdk = 35

    // Swift native libraries (compiled via Swift SDK for Android)
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    defaultConfig {
        applicationId = "com.flutterflow.foodshare"
        minSdk = 28  // Matches Swift SDK for Android requirement (API 28+)
        targetSdk = 35
        versionCode = 274
        versionName = "3.0.3"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        vectorDrawables {
            useSupportLibrary = true
        }

        // Inject Supabase credentials into BuildConfig
        buildConfigField("String", "SUPABASE_URL", "\"${localProperties.getProperty("SUPABASE_URL", "")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${localProperties.getProperty("SUPABASE_ANON_KEY", "")}\"")
        buildConfigField("String", "SENTRY_DSN", "\"${localProperties.getProperty("SENTRY_DSN", "")}\"")
        
        // Sentry config
        manifestPlaceholders["sentryDsn"] = localProperties.getProperty("SENTRY_DSN", "")
        
        // Native library configuration (skip on CI)
        // Note: C++ bridge removed - using swift-java for auto-generated JNI bindings
        if (!skipNativeBuild) {
            ndk {
                // Architectures supported by Swift SDK for Android
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("/Users/organic/dev/work/Creds/Google/foodshare-upload.keystore")
            storePassword = localProperties.getProperty("KEYSTORE_PASSWORD", "")
            keyAlias = localProperties.getProperty("KEY_ALIAS", "")
            keyPassword = localProperties.getProperty("KEY_PASSWORD", "")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        // Keep native libraries
        jniLibs {
            keepDebugSymbols += "**/*.so"
        }
    }
}

// Java toolchain to ensure consistent JDK version
kotlin {
    jvmToolchain(21)
}

// KSP arguments for Room and Hilt
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
    arg("room.incremental", "true")
    arg("room.expandProjection", "true")
}

// SwiftKit runtime repository is configured in settings.gradle.kts

dependencies {
    // SwiftKit runtime (JNI mode) - required for swift-java generated bindings
    // Using local JAR since not published to Maven Central
    implementation(files("libs/swiftkit-core-1.0-SNAPSHOT.jar"))

    // Hilt
    val hiltVersion = "2.51.1"
    implementation("com.google.dagger:hilt-android:$hiltVersion")
    ksp("com.google.dagger:hilt-compiler:$hiltVersion")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
    implementation("androidx.hilt:hilt-work:1.2.0")
    ksp("androidx.hilt:hilt-compiler:1.2.0")

    // Supabase
    val supabaseVersion = "3.0.3"
    implementation(platform("io.github.jan-tennert.supabase:bom:$supabaseVersion"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")

    // Ktor client for Supabase (OkHttp works better on Android)
    implementation("io.ktor:ktor-client-okhttp:3.0.2")

    // OkHttp for TranslationService
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    // Compose
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    // Compose Navigation
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // AndroidX
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    // Coil for image loading
    implementation("io.coil-kt:coil-compose:2.7.0")

    // Location
    implementation("com.google.android.gms:play-services-location:21.3.0")

    // Coroutines Play Services (for Task.await())
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    // Google Maps Compose
    implementation("com.google.maps.android:maps-compose:4.3.0")
    implementation("com.google.android.gms:play-services-maps:19.0.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // Room (for sync database)
    val roomVersion = "2.6.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    // WorkManager (for background sync)
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // DataStore (for preferences)
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Glance (Widgets)
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")

    // Biometric
    implementation("androidx.biometric:biometric:1.1.0")

    // Google Play Billing
    implementation("com.android.billingclient:billing-ktx:7.1.1")

    // Sentry for crash reporting
    implementation("io.sentry:sentry-android:8.5.0")
    implementation("io.sentry:sentry-compose-android:8.5.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

// ============================================================================
// Swift SDK for Android Integration (via swift-java)
// ============================================================================
//
// FoodshareCore is a Swift package that compiles natively for Android using
// the official Swift SDK for Android (https://www.swift.org/android-workgroup/).
//
// Architecture (using swift-java for auto-generated JNI bindings):
//   Swift Code (FoodshareCore) → swift-java jextract → Generated Java/Kotlin bindings
//   No manual C++ bridge required!
//
// Build process:
//   ./gradlew generateJniBindings  # Regenerate bindings when Swift changes
//   ./gradlew buildSwiftDebug      # Debug build for all architectures
//   ./gradlew buildSwiftRelease    # Release build for all architectures
//   ./gradlew assembleDebug        # Build Android app
//
// Native libraries location:
//   app/src/main/jniLibs/
//   ├── arm64-v8a/libFoodshareCore.so
//   └── x86_64/libFoodshareCore.so
//
// Generated bindings location:
//   app/src/main/java/com/foodshare/swift/generated/
//
// Integration chain:
//   ValidationBridge.kt → Generated Java Classes → Swift (via swift-java JNI)
//
// Usage in ViewModels:
//   val result = ValidationBridge.validateListing(title, description, quantity)
//   if (!result.isValid) { /* show errors */ }
//
// swift-java docs: https://github.com/swiftlang/swift-java
// ============================================================================

val swiftCoreDir = file("${rootProject.projectDir}/foodshare-core")

// Build Swift for Android (debug)
tasks.register<Exec>("buildSwiftDebug") {
    description = "Build FoodshareCore Swift library for Android (debug)"
    group = "swift"

    workingDir = swiftCoreDir
    commandLine = listOf("./scripts/build-android.sh", "all", "debug")

    doFirst {
        println("Building FoodshareCore for Android (debug)...")
    }

    doLast {
        println("Swift debug build complete!")
    }
}

// Build Swift for Android (release)
tasks.register<Exec>("buildSwiftRelease") {
    description = "Build FoodshareCore Swift library for Android (release)"
    group = "swift"

    workingDir = swiftCoreDir
    commandLine = listOf("./scripts/build-android.sh", "all", "release")

    doFirst {
        println("Building FoodshareCore for Android (release)...")
    }

    doLast {
        println("Swift release build complete!")
    }
}

// Run Swift tests
tasks.register<Exec>("testSwift") {
    description = "Run FoodshareCore Swift tests"
    group = "swift"

    workingDir = swiftCoreDir
    commandLine = listOf("swift", "test")

    doFirst {
        println("Running Swift tests...")
    }
}

// Clean Swift build artifacts
tasks.register<Delete>("cleanSwift") {
    description = "Clean FoodshareCore Swift build artifacts"
    group = "swift"

    delete(file("$swiftCoreDir/.build"))

    doFirst {
        println("Cleaning Swift build directory...")
    }
}

// Generate JNI bindings using swift-java jextract
tasks.register<Exec>("generateJniBindings") {
    description = "Generate Java/Kotlin bindings from Swift using swift-java jextract"
    group = "swift"

    workingDir = swiftCoreDir
    commandLine = listOf(
        System.getProperty("user.home") + "/bin/swift-java", "jextract",
        "--swift-module", "FoodshareCore",
        "--mode", "jni",
        "--input-swift", "Sources/FoodshareCore",
        "--output-java", "${rootProject.projectDir}/app/src/main/java",
        "--output-swift", "Sources/FoodshareCore/JNI/Generated",
        "--java-package", "com.foodshare.swift.generated"
    )

    doFirst {
        println("Generating JNI bindings with swift-java jextract...")
        // Create output directories if they don't exist
        file("${rootProject.projectDir}/app/src/main/java/com/foodshare/swift/generated").mkdirs()
        file("$swiftCoreDir/Sources/FoodshareCore/JNI/Generated").mkdirs()
    }

    doLast {
        println("JNI bindings generated successfully!")
    }
}


// ============================================================================
// Sentry Configuration
// ============================================================================
sentry {
    // Disable Sentry uploads in CI if auth token not available
    val hasSentryAuth = System.getenv("SENTRY_AUTH_TOKEN")?.isNotEmpty() == true 
        || localProperties.getProperty("SENTRY_AUTH_TOKEN", "").isNotEmpty()
    
    // Enables or disables the automatic upload of mapping files
    autoUploadProguardMapping.set(hasSentryAuth)
    
    // Enables or disables source context
    includeSourceContext.set(hasSentryAuth)
    
    // Organization and project
    org.set("foodshare")
    projectName.set("foodshare-android")
    
    // Auth token from environment or local.properties
    authToken.set(
        System.getenv("SENTRY_AUTH_TOKEN") 
            ?: localProperties.getProperty("SENTRY_AUTH_TOKEN", "")
    )
    
    // Tracing instrumentation
    tracingInstrumentation {
        enabled.set(true)
        features.set(setOf(
            io.sentry.android.gradle.extensions.InstrumentationFeature.DATABASE,
            io.sentry.android.gradle.extensions.InstrumentationFeature.FILE_IO,
            io.sentry.android.gradle.extensions.InstrumentationFeature.OKHTTP,
            io.sentry.android.gradle.extensions.InstrumentationFeature.COMPOSE
        ))
    }
}
