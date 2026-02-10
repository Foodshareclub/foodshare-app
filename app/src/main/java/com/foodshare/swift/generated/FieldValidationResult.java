package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift FieldValidationResult.
 * Contains single field validation results.
 */
@SuppressWarnings("unused")
public final class FieldValidationResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = FormValidationEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private FieldValidationResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static FieldValidationResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new FieldValidationResult(selfPointer, swiftArena);
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
     * Whether the field is valid.
     */
    public boolean isValid() {
        return $getIsValid(this.selfPointer);
    }

    private static native boolean $getIsValid(long selfPointer);

    /**
     * JSON array of error strings: ["error1", "error2"].
     */
    public String getErrors() {
        return $getErrors(this.selfPointer);
    }

    private static native String $getErrors(long selfPointer);

    /**
     * Number of errors.
     */
    public int getErrorCount() {
        return $getErrorCount(this.selfPointer);
    }

    private static native int $getErrorCount(long selfPointer);

    /**
     * First error message, or empty string if valid.
     */
    public String getFirstError() {
        return $getFirstError(this.selfPointer);
    }

    private static native String $getFirstError(long selfPointer);

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
                FieldValidationResult.$destroy(self$);
            }
        };
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return FieldValidationResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "FieldValidationResult{" +
                "isValid=" + isValid() +
                ", errorCount=" + getErrorCount() +
                ", firstError='" + getFirstError() + '\'' +
                '}';
    }
}
