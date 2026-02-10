package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift RetryDecisionResult.
 * Contains retry decision information.
 */
@SuppressWarnings("unused")
public final class RetryDecisionResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = BatchOperationsEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private RetryDecisionResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static RetryDecisionResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new RetryDecisionResult(selfPointer, swiftArena);
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

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> RetryDecisionResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return RetryDecisionResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "RetryDecisionResult{" +
                "canRetry=" + canRetry() +
                ", reason='" + getReason() + '\'' +
                '}';
    }
}
