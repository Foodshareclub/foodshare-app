package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift AuthMappedErrorResult.
 * Contains authentication error mapping results.
 */
@SuppressWarnings("unused")
public final class AuthMappedErrorResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = ErrorMappingEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private AuthMappedErrorResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static AuthMappedErrorResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new AuthMappedErrorResult(selfPointer, swiftArena);
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

    public String getMessage() {
        return $getMessage(this.selfPointer);
    }

    private static native String $getMessage(long selfPointer);

    public String getCategory() {
        return $getCategory(this.selfPointer);
    }

    private static native String $getCategory(long selfPointer);

    public boolean isRecoverable() {
        return $getIsRecoverable(this.selfPointer);
    }

    private static native boolean $getIsRecoverable(long selfPointer);

    public String getSuggestion() {
        return $getSuggestion(this.selfPointer);
    }

    private static native String $getSuggestion(long selfPointer);

    // ========================================================================
    // Lifecycle Management
    // ========================================================================

    private static native void $destroy(long selfPointer);

    @Override
    public Runnable $createDestroyFunction() {
        final long self$ = this.selfPointer;
        return () -> AuthMappedErrorResult.$destroy(self$);
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return AuthMappedErrorResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "AuthMappedErrorResult{" +
                "message='" + getMessage() + '\'' +
                ", category='" + getCategory() + '\'' +
                ", isRecoverable=" + isRecoverable() +
                ", suggestion='" + getSuggestion() + '\'' +
                '}';
    }
}
