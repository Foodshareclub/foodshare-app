package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift RecoveryStrategyResult.
 * Contains recovery strategy information for errors.
 */
@SuppressWarnings("unused")
public final class RecoveryStrategyResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = ErrorMappingEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private RecoveryStrategyResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static RecoveryStrategyResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new RecoveryStrategyResult(selfPointer, swiftArena);
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

    public String getPrimaryAction() {
        return $getPrimaryAction(this.selfPointer);
    }

    private static native String $getPrimaryAction(long selfPointer);

    public String getAlternativeActionsJson() {
        return $getAlternativeActionsJson(this.selfPointer);
    }

    private static native String $getAlternativeActionsJson(long selfPointer);

    public String getFallbackAction() {
        return $getFallbackAction(this.selfPointer);
    }

    private static native String $getFallbackAction(long selfPointer);

    public boolean isAutoRecoveryPossible() {
        return $getAutoRecoveryPossible(this.selfPointer);
    }

    private static native boolean $getAutoRecoveryPossible(long selfPointer);

    public double getRecommendedDelaySeconds() {
        return $getRecommendedDelaySeconds(this.selfPointer);
    }

    private static native double $getRecommendedDelaySeconds(long selfPointer);

    public int getMaxRetries() {
        return $getMaxRetries(this.selfPointer);
    }

    private static native int $getMaxRetries(long selfPointer);

    public boolean shouldRetry() {
        return $getShouldRetry(this.selfPointer);
    }

    private static native boolean $getShouldRetry(long selfPointer);

    public String getGuidanceTitle() {
        return $getGuidanceTitle(this.selfPointer);
    }

    private static native String $getGuidanceTitle(long selfPointer);

    public String getGuidanceMessage() {
        return $getGuidanceMessage(this.selfPointer);
    }

    private static native String $getGuidanceMessage(long selfPointer);

    public String getGuidanceActionLabel() {
        return $getGuidanceActionLabel(this.selfPointer);
    }

    private static native String $getGuidanceActionLabel(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> RecoveryStrategyResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return RecoveryStrategyResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "RecoveryStrategyResult{" +
                "primaryAction='" + getPrimaryAction() + '\'' +
                ", autoRecoveryPossible=" + isAutoRecoveryPossible() +
                ", maxRetries=" + getMaxRetries() +
                ", guidanceTitle='" + getGuidanceTitle() + '\'' +
                '}';
    }
}
