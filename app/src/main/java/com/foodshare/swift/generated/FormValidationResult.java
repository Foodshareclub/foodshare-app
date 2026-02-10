package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;
import org.swift.swiftkit.core.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift FormValidationResult.
 * Contains form validation results with field-level errors.
 */
@SuppressWarnings("unused")
public final class FormValidationResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = FormValidationEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private FormValidationResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static FormValidationResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new FormValidationResult(selfPointer, swiftArena);
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
     * Whether the form is valid.
     */
    public boolean isValid() {
        return $getIsValid(this.selfPointer);
    }

    private static native boolean $getIsValid(long selfPointer);

    /**
     * JSON object of field errors: {"fieldId": ["error1", "error2"]}.
     */
    public String getFieldErrors() {
        return $getFieldErrors(this.selfPointer);
    }

    private static native String $getFieldErrors(long selfPointer);

    /**
     * JSON array of all errors: ["error1", "error2", ...].
     */
    public String getAllErrors() {
        return $getAllErrors(this.selfPointer);
    }

    private static native String $getAllErrors(long selfPointer);

    /**
     * Total number of errors.
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
                FormValidationResult.$destroy(self$);
            }
        };
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return FormValidationResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "FormValidationResult{" +
                "isValid=" + isValid() +
                ", errorCount=" + getErrorCount() +
                ", firstError='" + getFirstError() + '\'' +
                '}';
    }
}
