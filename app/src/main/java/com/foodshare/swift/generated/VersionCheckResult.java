package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift VersionCheckResult.
 * Contains version compatibility check results.
 */
@SuppressWarnings("unused")
public final class VersionCheckResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = FeatureFlagEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private VersionCheckResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static VersionCheckResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new VersionCheckResult(selfPointer, swiftArena);
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
     * Whether the version is compatible.
     */
    public boolean isCompatible() {
        return $getIsCompatible(this.selfPointer);
    }

    private static native boolean $getIsCompatible(long selfPointer);

    /**
     * Reason for compatibility/incompatibility.
     */
    public String getReason() {
        return $getReason(this.selfPointer);
    }

    private static native String $getReason(long selfPointer);

    /**
     * Human-readable message about version compatibility.
     */
    public String getMessage() {
        return $getMessage(this.selfPointer);
    }

    private static native String $getMessage(long selfPointer);

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
                VersionCheckResult.$destroy(self$);
            }
        };
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return VersionCheckResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "VersionCheckResult{" +
                "isCompatible=" + isCompatible() +
                ", reason='" + getReason() + '\'' +
                ", message='" + getMessage() + '\'' +
                '}';
    }
}
