package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift BatchValidationResult.
 * Contains batch validation results.
 */
@SuppressWarnings("unused")
public final class SwiftBatchValidationResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = BatchOperationsEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private SwiftBatchValidationResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static SwiftBatchValidationResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new SwiftBatchValidationResult(selfPointer, swiftArena);
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

    public boolean isValid() {
        return $getIsValid(this.selfPointer);
    }

    private static native boolean $getIsValid(long selfPointer);

    public String getErrorsJson() {
        return $getErrorsJson(this.selfPointer);
    }

    private static native String $getErrorsJson(long selfPointer);

    public String getWarningsJson() {
        return $getWarningsJson(this.selfPointer);
    }

    private static native String $getWarningsJson(long selfPointer);

    public int getErrorCount() {
        return $getErrorCount(this.selfPointer);
    }

    private static native int $getErrorCount(long selfPointer);

    public int getWarningCount() {
        return $getWarningCount(this.selfPointer);
    }

    private static native int $getWarningCount(long selfPointer);

    public int getValidItemCount() {
        return $getValidItemCount(this.selfPointer);
    }

    private static native int $getValidItemCount(long selfPointer);

    public int getInvalidItemCount() {
        return $getInvalidItemCount(this.selfPointer);
    }

    private static native int $getInvalidItemCount(long selfPointer);

    public int getTotalItems() {
        return $getTotalItems(this.selfPointer);
    }

    private static native int $getTotalItems(long selfPointer);

    public double getSuccessRate() {
        return $getSuccessRate(this.selfPointer);
    }

    private static native double $getSuccessRate(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> SwiftBatchValidationResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return SwiftBatchValidationResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "SwiftBatchValidationResult{" +
                "isValid=" + isValid() +
                ", errorCount=" + getErrorCount() +
                ", warningCount=" + getWarningCount() +
                ", totalItems=" + getTotalItems() +
                ", successRate=" + getSuccessRate() +
                '}';
    }
}
