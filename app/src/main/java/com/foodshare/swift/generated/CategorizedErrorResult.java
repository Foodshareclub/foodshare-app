package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift CategorizedErrorResult.
 * Contains error categorization results.
 */
@SuppressWarnings("unused")
public final class CategorizedErrorResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = ErrorMappingEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private CategorizedErrorResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static CategorizedErrorResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new CategorizedErrorResult(selfPointer, swiftArena);
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

    public String getCategory() {
        return $getCategory(this.selfPointer);
    }

    private static native String $getCategory(long selfPointer);

    public String getSeverity() {
        return $getSeverity(this.selfPointer);
    }

    private static native String $getSeverity(long selfPointer);

    public boolean isTransient() {
        return $getIsTransient(this.selfPointer);
    }

    private static native boolean $getIsTransient(long selfPointer);

    public boolean isRetryable() {
        return $getIsRetryable(this.selfPointer);
    }

    private static native boolean $getIsRetryable(long selfPointer);

    public boolean requiresUserAction() {
        return $getRequiresUserAction(this.selfPointer);
    }

    private static native boolean $getRequiresUserAction(long selfPointer);

    public boolean shouldReport() {
        return $getShouldReport(this.selfPointer);
    }

    private static native boolean $getShouldReport(long selfPointer);

    public String getDisplayName() {
        return $getDisplayName(this.selfPointer);
    }

    private static native String $getDisplayName(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> CategorizedErrorResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return CategorizedErrorResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "CategorizedErrorResult{" +
                "category='" + getCategory() + '\'' +
                ", severity='" + getSeverity() + '\'' +
                ", isTransient=" + isTransient() +
                ", isRetryable=" + isRetryable() +
                ", displayName='" + getDisplayName() + '\'' +
                '}';
    }
}
