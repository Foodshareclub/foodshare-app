package com.foodshare.swift.generated;

import org.swift.swiftkit.core.*;

import org.swift.swiftkit.core.util.*;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Generated Java class for Swift VariantSelectionResult.
 * Contains experiment variant selection results.
 */
@SuppressWarnings("unused")
public final class VariantSelectionResult implements JNISwiftInstance, AutoCloseable {

    static final String LIB_NAME = "FoodshareCore";
    private static final boolean INITIALIZED_LIBS = FeatureFlagEngine.initializeLibs();

    private final long selfPointer;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    private VariantSelectionResult(long selfPointer, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;
        swiftArena.register(this);
    }

    static VariantSelectionResult wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
        return new VariantSelectionResult(selfPointer, swiftArena);
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
     * Index of the selected variant.
     */
    public int getVariantIndex() {
        return $getVariantIndex(this.selfPointer);
    }

    private static native int $getVariantIndex(long selfPointer);

    /**
     * User's bucket value used for selection.
     */
    public int getBucket() {
        return $getBucket(this.selfPointer);
    }

    private static native int $getBucket(long selfPointer);

    /**
     * Human-readable explanation of the selection.
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
                VariantSelectionResult.$destroy(self$);
            }
        };
    }

    private static native long $typeMetadataAddressDowncall();
    @Override
    public long $typeMetadataAddress() {
        return VariantSelectionResult.$typeMetadataAddressDowncall();
    }

    @Override
    public void close() {
        if (this.$state$destroyed.compareAndSet(false, true)) {
            $destroy(this.selfPointer);
        }
    }

    @Override
    public String toString() {
        return "VariantSelectionResult{" +
                "variantIndex=" + getVariantIndex() +
                ", bucket=" + getBucket() +
                ", explanation='" + getExplanation() + '\'' +
                '}';
    }
}
