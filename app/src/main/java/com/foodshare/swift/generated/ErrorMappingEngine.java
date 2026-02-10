package com.foodshare.swift.generated;

import org.swift.swiftkit.core.SwiftArena;

/**
 * Generated Java class for Swift ErrorMappingEngine.
 * Provides error categorization, recovery strategies, and user-friendly messages.
 */
@SuppressWarnings("unused")
public final class ErrorMappingEngine {

    static final String LIB_NAME = "FoodshareCore";
    private static volatile boolean LIBS_INITIALIZED = false;

    private ErrorMappingEngine() {
        // Static utility class
    }

    static boolean initializeLibs() {
        if (!LIBS_INITIALIZED) {
            synchronized (ErrorMappingEngine.class) {
                if (!LIBS_INITIALIZED) {
                    System.loadLibrary(LIB_NAME);
                    LIBS_INITIALIZED = true;
                }
            }
        }
        return true;
    }

    static {
        initializeLibs();
    }

    // ========================================================================
    // Error Categorization
    // ========================================================================

    /**
     * Categorize an error based on code, message, and status code.
     *
     * @param code Error code
     * @param message Error message
     * @param statusCode HTTP status code (0 if not applicable)
     * @param arena SwiftArena for memory management
     * @return CategorizedErrorResult
     */
    public static CategorizedErrorResult categorizeError(
            String code,
            String message,
            int statusCode,
            SwiftArena arena
    ) {
        long resultPtr = $categorizeError(code, message, statusCode);
        return CategorizedErrorResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $categorizeError(String code, String message, int statusCode);

    // ========================================================================
    // Recovery Strategy
    // ========================================================================

    /**
     * Get recovery strategy for an error category.
     *
     * @param category Error category string
     * @param arena SwiftArena for memory management
     * @return RecoveryStrategyResult
     */
    public static RecoveryStrategyResult getRecoveryStrategy(String category, SwiftArena arena) {
        long resultPtr = $getRecoveryStrategy(category);
        return RecoveryStrategyResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $getRecoveryStrategy(String category);

    // ========================================================================
    // User-Friendly Error
    // ========================================================================

    /**
     * Map an error to user-friendly display.
     *
     * @param code Error code
     * @param message Error message
     * @param statusCode HTTP status code (0 if not applicable)
     * @param arena SwiftArena for memory management
     * @return UserFriendlyErrorResult
     */
    public static UserFriendlyErrorResult mapToUserFriendlyError(
            String code,
            String message,
            int statusCode,
            SwiftArena arena
    ) {
        long resultPtr = $mapToUserFriendlyError(code, message, statusCode);
        return UserFriendlyErrorResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $mapToUserFriendlyError(String code, String message, int statusCode);

    // ========================================================================
    // Retry Eligibility
    // ========================================================================

    /**
     * Check retry eligibility for an error.
     *
     * @param category Error category string
     * @param attemptCount Current attempt count
     * @param arena SwiftArena for memory management
     * @return RetryEligibilityResult
     */
    public static RetryEligibilityResult checkRetryEligibility(
            String category,
            int attemptCount,
            SwiftArena arena
    ) {
        long resultPtr = $checkRetryEligibility(category, attemptCount);
        return RetryEligibilityResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $checkRetryEligibility(String category, int attemptCount);

    // ========================================================================
    // Auth Error Mapping
    // ========================================================================

    /**
     * Map authentication error to user-friendly message.
     *
     * @param errorMessage Error message from auth provider
     * @param errorCode Error code (optional, can be empty)
     * @param arena SwiftArena for memory management
     * @return AuthMappedErrorResult
     */
    public static AuthMappedErrorResult mapAuthError(
            String errorMessage,
            String errorCode,
            SwiftArena arena
    ) {
        long resultPtr = $mapAuthError(errorMessage, errorCode);
        return AuthMappedErrorResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $mapAuthError(String errorMessage, String errorCode);
}
