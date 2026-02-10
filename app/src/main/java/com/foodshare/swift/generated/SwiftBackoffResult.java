package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift BackoffResult.
 * Contains backoff calculation results.
 */
@SuppressWarnings("unused")
public final class SwiftBackoffResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = BatchOperationsEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private SwiftBackoffResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static SwiftBackoffResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new SwiftBackoffResult(selfPointer, swiftArena);
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

    public int getDelayMs() {
        return $getDelayMs(this.selfPointer);
    }

    private static native int $getDelayMs(long selfPointer);

    public double getDelaySeconds() {
        return $getDelaySeconds(this.selfPointer);
    }

    private static native double $getDelaySeconds(long selfPointer);

    public int getAttempt() {
        return $getAttempt(this.selfPointer);
    }

    private static native int $getAttempt(long selfPointer);

    public String getStrategy() {
        return $getStrategy(this.selfPointer);
    }

    private static native String $getStrategy(long selfPointer);

    public boolean isMaxDelay() {
        return $getIsMaxDelay(this.selfPointer);
    }

    private static native boolean $getIsMaxDelay(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> SwiftBackoffResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return SwiftBackoffResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "SwiftBackoffResult{" +
                "delayMs=" + getDelayMs() +
                ", delaySeconds=" + getDelaySeconds() +
                ", attempt=" + getAttempt() +
                ", strategy='" + getStrategy() + '\'' +
                ", isMaxDelay=" + isMaxDelay() +
                '}';
    }
}
