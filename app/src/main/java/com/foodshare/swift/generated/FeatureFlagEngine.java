package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;
import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift FeatureFlagEngine.
 * Provides cross-platform feature flag evaluation with deterministic rollout bucketing.
 */
@SuppressWarnings("unused")
public final class FeatureFlagEngine {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = initializeLibs();

    static boolean initializeLibs() {
        System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
        System.loadLibrary(LIB_NAME);
        return true;
    }

    private FeatureFlagEngine() {
        // Static utility class
    }

    // ========================================================================
    // Rollout Calculation
    // ========================================================================

    /**
     * Calculate rollout bucket and inclusion for a user.
     * Uses deterministic hashing for consistent bucketing across platforms.
     *
     * @param userId User identifier
     * @param percentage Rollout percentage (0-100)
     * @param flagId Optional flag ID for per-flag bucketing
     * @param arena SwiftArena for memory management
     * @return RolloutResult with bucket info
     */
    public static RolloutResult calculateRollout(
            String userId,
            int percentage,
            String flagId,
            SwiftArena arena
    ) {
        long resultPtr = $calculateRollout(userId, percentage, flagId);
        return RolloutResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $calculateRollout(String userId, int percentage, String flagId);

    /**
     * Get the user's rollout bucket for a flag.
     *
     * @param userId User identifier
     * @param flagId Flag identifier (empty string for user-only bucketing)
     * @return Bucket value (0-99)
     */
    public static int calculateRolloutBucket(String userId, String flagId) {
        return $calculateRolloutBucket(userId, flagId);
    }

    private static native int $calculateRolloutBucket(String userId, String flagId);

    // ========================================================================
    // Version Compatibility
    // ========================================================================

    /**
     * Check version compatibility for a feature flag.
     *
     * @param appVersion Current app version
     * @param minVersion Minimum required version (empty string if none)
     * @param maxVersion Maximum allowed version (empty string if none)
     * @param arena SwiftArena for memory management
     * @return VersionCheckResult
     */
    public static VersionCheckResult checkVersionCompatibility(
            String appVersion,
            String minVersion,
            String maxVersion,
            SwiftArena arena
    ) {
        long resultPtr = $checkVersionCompatibility(appVersion, minVersion, maxVersion);
        return VersionCheckResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $checkVersionCompatibility(String appVersion, String minVersion, String maxVersion);

    // ========================================================================
    // Segment Matching
    // ========================================================================

    /**
     * Check if user segments match any target segments.
     *
     * @param userSegments Comma-separated user segment IDs
     * @param targetSegments Comma-separated target segment IDs
     * @return true if any segment matches
     */
    public static boolean matchesSegments(String userSegments, String targetSegments) {
        return $matchesSegments(userSegments, targetSegments);
    }

    private static native boolean $matchesSegments(String userSegments, String targetSegments);

    // ========================================================================
    // Platform Matching
    // ========================================================================

    /**
     * Check if a platform matches target platforms.
     *
     * @param userPlatform User's platform (e.g., "ios", "android")
     * @param targetPlatforms Comma-separated target platforms
     * @return true if platform matches or no targets specified
     */
    public static boolean matchesPlatform(String userPlatform, String targetPlatforms) {
        return $matchesPlatform(userPlatform, targetPlatforms);
    }

    private static native boolean $matchesPlatform(String userPlatform, String targetPlatforms);

    // ========================================================================
    // Weighted Variant Selection
    // ========================================================================

    /**
     * Select a variant using weighted random selection with deterministic bucketing.
     *
     * @param userId User identifier for deterministic selection
     * @param experimentId Experiment identifier
     * @param salt Salt for additional randomization
     * @param weights Comma-separated weights (e.g., "50.0,30.0,20.0")
     * @param arena SwiftArena for memory management
     * @return VariantSelectionResult with selected index
     */
    public static VariantSelectionResult weightedSelect(
            String userId,
            String experimentId,
            String salt,
            String weights,
            SwiftArena arena
    ) {
        long resultPtr = $weightedSelect(userId, experimentId, salt, weights);
        return VariantSelectionResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $weightedSelect(String userId, String experimentId, String salt, String weights);

    // ========================================================================
    // Targeting Evaluation
    // ========================================================================

    /**
     * Evaluate experiment targeting with percentage.
     *
     * @param userId User identifier
     * @param targetingPercentage Percentage of users to target (0-100)
     * @param includedUserIds Comma-separated included user IDs
     * @param excludedUserIds Comma-separated excluded user IDs
     * @return true if user passes targeting
     */
    public static boolean evaluateTargeting(
            String userId,
            int targetingPercentage,
            String includedUserIds,
            String excludedUserIds
    ) {
        return $evaluateTargeting(userId, targetingPercentage, includedUserIds, excludedUserIds);
    }

    private static native boolean $evaluateTargeting(
            String userId,
            int targetingPercentage,
            String includedUserIds,
            String excludedUserIds
    );

    // ========================================================================
    // Hash Function (for testing/debugging)
    // ========================================================================

    /**
     * Calculate djb2 hash of a string.
     * Useful for verifying cross-platform consistency.
     *
     * @param input Input string to hash
     * @return Hash value
     */
    public static long djb2Hash(String input) {
        return $djb2Hash(input);
    }

    private static native long $djb2Hash(String input);
}
