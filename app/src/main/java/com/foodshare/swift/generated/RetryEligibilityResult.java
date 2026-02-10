package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift RetryEligibilityResult.
 * Contains retry eligibility information for errors.
 */
@SuppressWarnings("unused")
public final class RetryEligibilityResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = ErrorMappingEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private RetryEligibilityResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static RetryEligibilityResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new RetryEligibilityResult(selfPointer, swiftArena);
    }

    @Override
    public long $memoryAddress() {
        return this.selfPointer;
    }

    @Override
    public AtomicBoolean $statusDestroyedFlag() {
        return this.$state$destroyed;
    }

    // ========================================================================
    // Property Accessors
    // ========================================================================

    public boolean canRetry() {
        return $getCanRetry(this.selfPointer);
    }

    private static native boolean $getCanRetry(long selfPointer);

    public String getReason() {
        return $getReason(this.selfPointer);
    }

    private static native String $getReason(long selfPointer);

    public int getRecommendedDelayMs() {
        return $getRecommendedDelayMs(this.selfPointer);
    }

    private static native int $getRecommendedDelayMs(long selfPointer);

    public double getConfidence() {
        return $getConfidence(this.selfPointer);
    }

    private static native double $getConfidence(long selfPointer);

    public int getMaxAttempts() {
        return $getMaxAttempts(this.selfPointer);
    }

    private static native int $getMaxAttempts(long selfPointer);

    public double getBackoffMultiplier() {
        return $getBackoffMultiplier(this.selfPointer);
    }

    private static native double $getBackoffMultiplier(long selfPointer);

    public boolean useJitter() {
        return $getUseJitter(this.selfPointer);
    }

    private static native boolean $getUseJitter(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> RetryEligibilityResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return RetryEligibilityResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "RetryEligibilityResult{" +
                "canRetry=" + canRetry() +
                ", reason='" + getReason() + '\'' +
                ", recommendedDelayMs=" + getRecommendedDelayMs() +
                ", maxAttempts=" + getMaxAttempts() +
                '}';
    }
}
