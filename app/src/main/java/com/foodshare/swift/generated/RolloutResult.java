package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift RolloutResult.
 * Contains rollout calculation results for feature flags.
 */
@SuppressWarnings("unused")
public final class RolloutResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = FeatureFlagEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private RolloutResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static RolloutResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new RolloutResult(selfPointer, swiftArena);
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

    /**
     * Whether the user is included in the rollout.
     */
    public boolean isIncluded() {
        return $getIsIncluded(this.selfPointer);
    }

    private static native boolean $getIsIncluded(long selfPointer);

    /**
     * User's bucket value (0-99).
     */
    public int getBucket() {
        return $getBucket(this.selfPointer);
    }

    private static native int $getBucket(long selfPointer);

    /**
     * Rollout percentage threshold.
     */
    public int getPercentage() {
        return $getPercentage(this.selfPointer);
    }

    private static native int $getPercentage(long selfPointer);

    /**
     * Human-readable explanation of the rollout result.
     */
    public String getExplanation() {
        return $getExplanation(this.selfPointer);
    }

    private static native String $getExplanation(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return new Runnable() {
            @Override
            public void run() {
                RolloutResult.$destroy(self$);
            }
        };
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return RolloutResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "RolloutResult{" +
                "isIncluded=" + isIncluded() +
                ", bucket=" + getBucket() +
                ", percentage=" + getPercentage() +
                ", explanation='" + getExplanation() + '\'' +
                '}';
    }
}
