package com.foodshare.swift.generated;

import org.swift.swiftkit.core.SwiftArena;

/**
 * Generated Java class for Swift BatchOperationsEngine.
 * Provides batch operation utilities with cross-platform consistent behavior.
 */
@SuppressWarnings("unused")
public final class BatchOperationsEngine {

    static final String LIB_NAME = "FoodshareCore";
    private static volatile boolean LIBS_INITIALIZED = false;

    private BatchOperationsEngine() {
        // Static utility class
    }

    static boolean initializeLibs() {
        if (!LIBS_INITIALIZED) {
            synchronized (BatchOperationsEngine.class) {
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
    // Chunk Size Calculation
    // ========================================================================

    /**
     * Calculate optimal chunk size for batch processing.
     *
     * @param totalItems Total number of items
     * @param connectionQuality Connection quality string
     * @param averageItemSizeBytes Average item size (0 if unknown)
     * @param defaultChunkSize Default chunk size
     * @param minChunkSize Minimum chunk size
     * @param maxChunkSize Maximum chunk size
     * @param maxBytesPerChunk Maximum bytes per chunk
     * @param arena SwiftArena for memory management
     * @return SwiftChunkSizeResult
     */
    public static SwiftChunkSizeResult calculateOptimalChunkSize(
            int totalItems,
            String connectionQuality,
            int averageItemSizeBytes,
            int defaultChunkSize,
            int minChunkSize,
            int maxChunkSize,
            int maxBytesPerChunk,
            SwiftArena arena
    ) {
        long resultPtr = $calculateOptimalChunkSize(
            totalItems, connectionQuality, averageItemSizeBytes,
            defaultChunkSize, minChunkSize, maxChunkSize, maxBytesPerChunk
        );
        return SwiftChunkSizeResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $calculateOptimalChunkSize(
        int totalItems, String connectionQuality, int averageItemSizeBytes,
        int defaultChunkSize, int minChunkSize, int maxChunkSize, int maxBytesPerChunk
    );

    // ========================================================================
    // Backoff Calculation
    // ========================================================================

    /**
     * Calculate backoff delay for retry attempt.
     *
     * @param attempt Current attempt number (0-based)
     * @param strategy Backoff strategy string
     * @param baseDelayMs Base delay in milliseconds
     * @param maxDelayMs Maximum delay in milliseconds
     * @param arena SwiftArena for memory management
     * @return SwiftBackoffResult
     */
    public static SwiftBackoffResult calculateBackoff(
            int attempt,
            String strategy,
            int baseDelayMs,
            int maxDelayMs,
            SwiftArena arena
    ) {
        long resultPtr = $calculateBackoff(attempt, strategy, baseDelayMs, maxDelayMs);
        return SwiftBackoffResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $calculateBackoff(int attempt, String strategy, int baseDelayMs, int maxDelayMs);

    // ========================================================================
    // Retry Decision
    // ========================================================================

    /**
     * Determine if an error is retryable.
     *
     * @param errorCategory Error category string
     * @param retryCount Current retry count
     * @param maxRetries Maximum retries
     * @param retryNetworkErrors Whether to retry network errors
     * @param retryTimeouts Whether to retry timeouts
     * @param retryConflicts Whether to retry conflicts
     * @param retryUnknownErrors Whether to retry unknown errors
     * @param arena SwiftArena for memory management
     * @return RetryDecisionResult
     */
    public static RetryDecisionResult isRetryable(
            String errorCategory,
            int retryCount,
            int maxRetries,
            boolean retryNetworkErrors,
            boolean retryTimeouts,
            boolean retryConflicts,
            boolean retryUnknownErrors,
            SwiftArena arena
    ) {
        long resultPtr = $isRetryable(
            errorCategory, retryCount, maxRetries,
            retryNetworkErrors, retryTimeouts, retryConflicts, retryUnknownErrors
        );
        return RetryDecisionResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $isRetryable(
        String errorCategory, int retryCount, int maxRetries,
        boolean retryNetworkErrors, boolean retryTimeouts, boolean retryConflicts, boolean retryUnknownErrors
    );

    // ========================================================================
    // Batch Validation
    // ========================================================================

    /**
     * Validate batch operation parameters.
     *
     * @param itemCount Number of items
     * @param operationType Operation type string
     * @param minBatchSize Minimum batch size
     * @param maxBatchSize Maximum batch size
     * @param allowBatchDelete Whether delete is allowed
     * @param arena SwiftArena for memory management
     * @return SwiftBatchValidationResult
     */
    public static SwiftBatchValidationResult validateBatchOperation(
            int itemCount,
            String operationType,
            int minBatchSize,
            int maxBatchSize,
            boolean allowBatchDelete,
            SwiftArena arena
    ) {
        long resultPtr = $validateBatchOperation(itemCount, operationType, minBatchSize, maxBatchSize, allowBatchDelete);
        return SwiftBatchValidationResult.wrapMemoryAddressUnsafe(resultPtr, arena);
    }

    private static native long $validateBatchOperation(
        int itemCount, String operationType, int minBatchSize, int maxBatchSize, boolean allowBatchDelete
    );
}
